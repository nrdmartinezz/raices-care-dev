import 'package:flutter_test/flutter_test.dart';
import 'package:raices/features/auth/domain/app_user.dart';
import 'package:raices/features/weather/domain/garden_weather.dart';

void main() {
  test('formats celsius and fahrenheit to the nearest degree', () {
    expect(formatTemperature(0, TemperatureUnit.fahrenheit), '32°F');
    expect(formatTemperature(22.2, TemperatureUnit.fahrenheit), '72°F');
    expect(formatTemperature(24, TemperatureUnit.celsius), '24°C');
    expect(formatTemperature(-5, TemperatureUnit.celsius), '-5°C');
  });

  test('rounds humidity to the nearest percent', () {
    expect(formatHumidity(48.4), '48%');
    expect(formatHumidity(48.5), '49%');
  });
}
