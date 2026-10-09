import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/local/app_database.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/data/hardiness_zone_repository.dart';
import '../../plants/data/species_repository.dart';
import '../domain/sowing_calendar.dart';

const frostCacheCollection = 'frost';

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
    this.remembered = false,
  });

  final String? zone;
  final FrostDates frost;
  final double latitude;
  final double longitude;

  /// True when these dates are the last successful lookup for this ZIP.
  /// A later 404 kept them. Sowing windows still need a live station.
  final bool remembered;
}

Future<void> saveRememberedFrost({
  required AppDatabase database,
  required String zip,
  required GardenFrostReady frost,
}) {
  return database.saveDocument(
    collection: frostCacheCollection,
    id: zip,
    payload: jsonEncode({
      'lastSpringFrost': frost.frost.lastSpringFrost,
      'firstFallFrost': frost.frost.firstFallFrost,
      'label': frost.frost.label,
      'zone': frost.zone,
      'latitude': frost.latitude,
      'longitude': frost.longitude,
    }),
  );
}

/// The saved frost calendar for [zip], or null when this ZIP has none.
Future<GardenFrostReady?> readRememberedFrost({
  required AppDatabase database,
  required String zip,
  String? zone,
}) async {
  final row = await database.readDocument(frostCacheCollection, zip);
  if (row == null) return null;
  return decodeRememberedFrost(row.payload, zone: zone);
}

GardenFrostReady? decodeRememberedFrost(String payload, {String? zone}) {
  Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final lastSpring = decoded['lastSpringFrost'];
  final firstFall = decoded['firstFallFrost'];
  final latitude = decoded['latitude'];
  final longitude = decoded['longitude'];
  if (lastSpring is! String || lastSpring.isEmpty) return null;
  if (firstFall is! String || firstFall.isEmpty) return null;
  if (latitude is! num || longitude is! num) return null;
  final storedZone = decoded['zone'];
  final label = decoded['label'];
  final profileZone = zone != null && zone.isNotEmpty ? zone : null;
  final cachedZone = storedZone is String && storedZone.isNotEmpty
      ? storedZone
      : null;
  return GardenFrostReady(
    zone: profileZone ?? cachedZone,
    frost: FrostDates(
      lastSpringFrost: lastSpring,
      firstFallFrost: firstFall,
      label: label is String && label.isNotEmpty ? label : '30-year averages',
    ),
    latitude: latitude.toDouble(),
    longitude: longitude.toDouble(),
    remembered: true,
  );
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
  if (usesWorkerApi) {
    return PlantingRepository(ref.watch(apiClientProvider));
  }
  final base = plantingApiBase;
  if (base == null) return null;
  return PlantingRepository(
    ApiClient(auth: ref.watch(firebaseAuthProvider), baseUrl: base),
  );
});

final gardenFrostProvider = FutureProvider<GardenFrost>((ref) async {
  ref.keepAlive();
  final profile = await ref.watch(userProfileProvider.future);
  final zip = profile?.homeLocation.postalCode?.trim();
  final savedZone = profile?.homeLocation.hardinessZone?.trim();
  if (zip == null || zip.isEmpty) {
    return const GardenFrostMissingZip();
  }

  final database = ref.watch(appDatabaseProvider);
  final zoneFallback = savedZone != null && savedZone.isNotEmpty
      ? savedZone
      : null;

  try {
    final lookedUp = await ref
        .watch(hardinessZoneRepositoryProvider)
        .lookup(zip);
    final zone = zoneFallback ?? lookedUp.zone;
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
    final ready = GardenFrostReady(
      zone: zone,
      frost: frost,
      latitude: latitude,
      longitude: longitude,
    );
    await saveRememberedFrost(database: database, zip: zip, frost: ready);
    return ready;
  } on ZoneLookupException {
    return GardenFrostUnavailable(zone: zoneFallback);
  } on NotFoundException {
    final remembered = await readRememberedFrost(
      database: database,
      zip: zip,
      zone: zoneFallback,
    );
    return remembered ?? GardenFrostUnavailable(zone: zoneFallback);
  } on AppException {
    return GardenFrostUnavailable(zone: zoneFallback);
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
  if (garden is! GardenFrostReady || garden.remembered) return null;
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
