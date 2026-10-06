import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/weather/data/weather_providers.dart';
import '../../features/weather/domain/garden_weather.dart';
import '../theme.dart';

/// A one-line reading for headers that are not the home screen.
///
/// Temperature, place, and humidity only. The sun icon and the card stay on
/// the home strip.
class HeaderWeather extends ConsumerWidget {
  const HeaderWeather({super.key, this.textAlign = TextAlign.start});

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(gardenWeatherProvider);
    final unit =
        ref.watch(userProfileProvider).value?.units.temperature ??
        TemperatureUnit.fahrenheit;

    return weather.maybeWhen(
      data: (reading) => Text.rich(
        _line(reading, unit),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

TextSpan _line(GardenWeather reading, TemperatureUnit unit) {
  final quiet = AppText.body.copyWith(color: AppColors.muted);
  final parts = <InlineSpan>[
    TextSpan(
      text: formatTemperature(reading.temperatureCelsius, unit),
      style: quiet.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
    if (reading.place.isNotEmpty)
      TextSpan(text: '  ·  ${reading.place}', style: quiet),
    if (reading.humidityPercent case final humidity?)
      TextSpan(text: '  ·  ${formatHumidity(humidity)}', style: quiet),
  ];
  return TextSpan(children: parts);
}
