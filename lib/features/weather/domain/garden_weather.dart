import '../../auth/domain/app_user.dart';

/// A current reading for the home strip.
///
/// Temperature is stored in Celsius, which is what the observation reports.
/// The strip converts it when it draws.
class GardenWeather {
  const GardenWeather({
    required this.temperatureCelsius,
    required this.sky,
    required this.place,
    this.humidityPercent,
  });

  final double temperatureCelsius;

  /// The station's own description, such as "Partly Cloudy".
  final String sky;

  /// "Austin, TX", from the forecast point's relative location.
  final String place;

  final double? humidityPercent;
}

/// A forecast lookup that should be shown on the strip, not retried silently.
class WeatherLookupException implements Exception {
  const WeatherLookupException(this.title, this.message);

  final String title;
  final String message;

  @override
  String toString() => '$title: $message';
}

/// Rounds to the nearest degree and appends the unit mark.
String formatTemperature(double celsius, TemperatureUnit unit) {
  final degrees = switch (unit) {
    TemperatureUnit.celsius => celsius,
    TemperatureUnit.fahrenheit => celsius * 9 / 5 + 32,
  };
  return '${degrees.round()}°${unit.wire}';
}

/// Rounds to the nearest percent.
String formatHumidity(num percent) => '${percent.round()}%';
