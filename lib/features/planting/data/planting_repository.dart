import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/data/hardiness_zone_repository.dart';
import '../../plants/data/species_repository.dart';
import '../domain/sowing_calendar.dart';

class FrostDates {
  const FrostDates({
    required this.lastSpringFrost,
    required this.firstFallFrost,
    required this.label,
  });

  final String lastSpringFrost;
  final String firstFallFrost;
  final String label;

  factory FrostDates.fromJson(Map<String, dynamic> json) => FrostDates(
    lastSpringFrost: json['lastSpringFrost'] as String? ?? '',
    firstFallFrost: json['firstFallFrost'] as String? ?? '',
    label: json['label'] as String? ?? '30-year averages',
  );
}

sealed class GardenFrost {
  const GardenFrost();
}

class GardenFrostMissingZip extends GardenFrost {
  const GardenFrostMissingZip();
}

class GardenFrostUnavailable extends GardenFrost {
  const GardenFrostUnavailable({this.zone});

  final String? zone;
}

class GardenFrostReady extends GardenFrost {
  const GardenFrostReady({
    required this.zone,
    required this.frost,
    required this.latitude,
    required this.longitude,
  });

  final String? zone;
  final FrostDates frost;
  final double latitude;
  final double longitude;
}

class PlantingRepository {
  const PlantingRepository(this._client);

  final ApiClient _client;

  Future<FrostDates> frost({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _client.getJson(
      '/v1/planting/frost',
      query: {'lat': latitude, 'lon': longitude},
    );
    return FrostDates.fromJson(json);
  }

  Future<SowingCalendar> species({
    required String name,
    String? commonName,
    required double latitude,
    required double longitude,
  }) async {
    final json = await _client.getJson(
      '/v1/planting/species',
      query: {
        'name': name,
        'lat': latitude,
        'lon': longitude,
        if (commonName != null && commonName.isNotEmpty) 'common': commonName,
      },
    );
    return SowingCalendar.fromJson(json);
  }

  Future<Map<String, bool?>> seasons({
    required double latitude,
    required double longitude,
    required List<String> names,
  }) async {
    final seasons = <String, bool?>{};
    final unique = names.where((name) => name.trim().isNotEmpty).toSet();
    final list = unique.toList();
    for (var index = 0; index < list.length; index += 20) {
      final slice = list.sublist(
        index,
        index + 20 > list.length ? list.length : index + 20,
      );
      final json = await _client.getJson(
        '/v1/planting/season',
        query: {'lat': latitude, 'lon': longitude, 'names': slice.join(',')},
      );
      final results = json['results'];
      if (results is! List) continue;
      for (final result in results) {
        if (result is! Map) continue;
        final name = result['name'];
        if (name is! String || name.isEmpty) continue;
        final inSeason = result['inSeason'];
        seasons[name.toLowerCase()] = inSeason is bool ? inSeason : null;
      }
    }
    return seasons;
  }
}

final plantingRepositoryProvider = Provider<PlantingRepository?>((ref) {
  if (!usesWorkerApi) return null;
  return PlantingRepository(ref.watch(apiClientProvider));
});

final gardenFrostProvider = FutureProvider<GardenFrost>((ref) async {
  ref.keepAlive();
  final profile = await ref.watch(userProfileProvider.future);
  final zip = profile?.homeLocation.postalCode?.trim();
  final savedZone = profile?.homeLocation.hardinessZone?.trim();
  if (zip == null || zip.isEmpty) {
    return const GardenFrostMissingZip();
  }

  try {
    final lookedUp = await ref
        .watch(hardinessZoneRepositoryProvider)
        .lookup(zip);
    final zone = (savedZone != null && savedZone.isNotEmpty)
        ? savedZone
        : lookedUp.zone;
    final latitude = lookedUp.latitude;
    final longitude = lookedUp.longitude;
    if (latitude == null || longitude == null) {
      return GardenFrostUnavailable(zone: zone);
    }
    final repository = ref.watch(plantingRepositoryProvider);
    if (repository == null) {
      return GardenFrostUnavailable(zone: zone);
    }
    final frost = await repository.frost(
      latitude: latitude,
      longitude: longitude,
    );
    return GardenFrostReady(
      zone: zone,
      frost: frost,
      latitude: latitude,
      longitude: longitude,
    );
  } on ZoneLookupException {
    return GardenFrostUnavailable(
      zone: savedZone != null && savedZone.isNotEmpty ? savedZone : null,
    );
  } on NotFoundException {
    return GardenFrostUnavailable(
      zone: savedZone != null && savedZone.isNotEmpty ? savedZone : null,
    );
  } on AppException {
    return GardenFrostUnavailable(
      zone: savedZone != null && savedZone.isNotEmpty ? savedZone : null,
    );
  }
});

Future<SowingCalendar?> _loadSowing({
  required PlantingRepository? repository,
  required GardenFrost garden,
  required SowingRequest request,
}) async {
  if (repository == null || request.scientificName.trim().length < 2) {
    return null;
  }
  if (garden is! GardenFrostReady) return null;
  try {
    return await repository.species(
      name: request.scientificName,
      commonName: request.commonName,
      latitude: garden.latitude,
      longitude: garden.longitude,
    );
  } on NotFoundException {
    return null;
  }
}

final sowingForSpeciesProvider = FutureProvider.autoDispose
    .family<SowingCalendar?, String>((ref, speciesId) async {
      if (speciesId.trim().isEmpty) return null;
      final speciesFuture = ref.watch(speciesProvider(speciesId).future);
      final gardenFuture = ref.watch(gardenFrostProvider.future);
      final repository = ref.watch(plantingRepositoryProvider);
      final species = await speciesFuture;
      if (species == null) return null;
      return _loadSowing(
        repository: repository,
        garden: await gardenFuture,
        request: SowingRequest(
          scientificName: species.scientificName,
          commonName: species.commonName,
        ),
      );
    });

final sowingCalendarProvider = FutureProvider.autoDispose
    .family<SowingCalendar?, SowingRequest>((ref, request) async {
      final gardenFuture = ref.watch(gardenFrostProvider.future);
      final repository = ref.watch(plantingRepositoryProvider);
      return _loadSowing(
        repository: repository,
        garden: await gardenFuture,
        request: request,
      );
    });
