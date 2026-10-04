import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/data/hardiness_zone_repository.dart';
import '../../onboarding/domain/hardiness_zone.dart';
import '../domain/garden_weather.dart';
import 'weather_repository.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WeatherRepository(client: client);
});

const _missingZip = WeatherLookupException(
  'Add your ZIP',
  'Finish garden setup to see the weather here.',
);

const _missingPoint = WeatherLookupException(
  'Weather unavailable',
  'The forecast could not be loaded.',
);

/// The reading for the home strip.
///
/// Kept alive for the session, so leaving the home tab and coming back does
/// not call the forecast service again. A new ZIP on the profile still
/// refetches.
final gardenWeatherProvider = FutureProvider<GardenWeather>((ref) async {
  ref.keepAlive();
  final profile = await ref.watch(userProfileProvider.future);
  final zip = profile?.homeLocation.postalCode?.trim();
  if (zip == null || zip.isEmpty) {
    throw _missingZip;
  }

  late final HardinessZone zone;
  try {
    zone = await ref.watch(hardinessZoneRepositoryProvider).lookup(zip);
  } on ZoneLookupException catch (error) {
    throw WeatherLookupException('Weather unavailable', error.message);
  }

  final latitude = zone.latitude;
  final longitude = zone.longitude;
  if (latitude == null || longitude == null) {
    throw _missingPoint;
  }

  return ref
      .watch(weatherRepositoryProvider)
      .current(latitude: latitude, longitude: longitude);
});
