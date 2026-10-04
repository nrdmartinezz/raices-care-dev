import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/garden_weather.dart';
import 'weather_repository.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WeatherRepository(client: client);
});

/// The reading for the home strip.
///
/// Kept alive for the session, so leaving the home tab and coming back does
/// not call the forecast service again.
final gardenWeatherProvider = FutureProvider<GardenWeather>((ref) async {
  ref.keepAlive();
  return ref.watch(weatherRepositoryProvider).current();
});
