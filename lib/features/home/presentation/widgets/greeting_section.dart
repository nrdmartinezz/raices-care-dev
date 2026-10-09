import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/app_user.dart';
import '../../../weather/data/weather_providers.dart';
import '../../../weather/domain/garden_weather.dart';
import '../../data/home_providers.dart';
import 'section_state.dart';

/// Section 1: the date, greeting and next-ritual pill, above the weather strip.
///
/// [compact] is the desktop header: the greeting sits on one line, and the
/// weather strip moves into the column beside Today's Ritual.
class GreetingSection extends ConsumerWidget {
  const GreetingSection({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(greetingProvider);
    final greeting = compact
        ? heading.greeting.replaceAll('\n', ' ')
        : heading.greeting;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading.date,
          style: AppText.eyebrow.copyWith(color: AppColors.green),
        ),
        SizedBox(height: compact ? 4 : 2.5),
        Text(
          greeting,
          style: AppText.display.copyWith(color: AppColors.ink),
        ),
      ],
    );

    if (compact) {
      return copy;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.5),
                  child: copy,
                ),
              ),
              const _RitualPill(),
            ],
          ),
          const SizedBox(height: 8),
          const GardenWeatherStrip(),
        ],
      ),
    );
  }
}

class _RitualPill extends ConsumerWidget {
  const _RitualPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppSizes.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(AppIcons.morningWatering, width: 16.5, height: 16.5),
          const SizedBox(width: 6),
          Text(
            ref.watch(ritualPillProvider),
            style: AppText.label.copyWith(color: AppColors.greenSoft),
          ),
        ],
      ),
    );
  }
}

/// The warm weather card. On desktop it also carries the next-ritual line.
class GardenWeatherStrip extends ConsumerWidget {
  const GardenWeatherStrip({super.key, this.showRitual = false});

  final bool showRitual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(gardenWeatherProvider);
    final unit =
        ref.watch(userProfileProvider).value?.units.temperature ??
        TemperatureUnit.fahrenheit;

    return weather.when(
      loading: () => const SectionSkeleton(rows: 1, height: 72),
      error: (error, _) => SectionMessage(
        title: error is WeatherLookupException
            ? error.title
            : 'Weather unavailable',
        body: error is WeatherLookupException
            ? error.message
            : 'The forecast could not be loaded.',
      ),
      data: (reading) => _WeatherReading(
        reading: reading,
        unit: unit,
        showRitual: showRitual,
      ),
    );
  }
}

class _WeatherReading extends ConsumerWidget {
  const _WeatherReading({
    required this.reading,
    required this.unit,
    required this.showRitual,
  });

  final GardenWeather reading;
  final TemperatureUnit unit;
  final bool showRitual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final humidity = reading.humidityPercent;
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = _WeatherSummary(reading: reading, unit: unit);
          final chips = humidity == null
              ? null
              : _WeatherChip(
                  icon: AppIcons.weatherHumidity,
                  iconSize: const Size(10.667, 13.333),
                  label: formatHumidity(humidity),
                  horizontal: showRitual,
                );
          final ritual = showRitual ? const _RitualAside() : null;
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SunBadge(),
                    const SizedBox(width: 10),
                    Expanded(child: summary),
                  ],
                ),
                if (chips != null || ritual != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ?chips,
                      const Spacer(),
                      ?ritual,
                    ],
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              const _SunBadge(),
              const SizedBox(width: 10),
              Expanded(child: summary),
              if (chips != null) ...[const SizedBox(width: 12), chips],
              if (ritual != null) ...[const SizedBox(width: 12), ritual],
            ],
          );
        },
      ),
    );
  }
}

class _SunBadge extends StatelessWidget {
  const _SunBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceBlush,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(AppIcons.weatherSun, width: 22, height: 22),
    );
  }
}

class _WeatherSummary extends StatelessWidget {
  const _WeatherSummary({required this.reading, required this.unit});

  final GardenWeather reading;
  final TemperatureUnit unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatTemperature(reading.temperatureCelsius, unit),
              style: AppText.metric.copyWith(color: AppColors.ink),
            ),
            if (reading.sky.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  reading.sky,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMedium.copyWith(color: AppColors.body),
                ),
              ),
            ],
          ],
        ),
        if (reading.place.isNotEmpty)
          Text(
            reading.place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(color: AppColors.green),
          ),
      ],
    );
  }
}

class _RitualAside extends ConsumerWidget {
  const _RitualAside();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(ritualPillProvider);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      label,
      textAlign: TextAlign.right,
      style: AppText.label.copyWith(color: AppColors.greenSoft),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.icon,
    required this.iconSize,
    required this.label,
    this.horizontal = false,
  });

  final String icon;
  final Size iconSize;
  final String label;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final glyph = SvgPicture.asset(
      icon,
      width: iconSize.width,
      height: iconSize.height,
    );
    final text = Text(label, style: AppText.label.copyWith(color: AppColors.ink));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppShadows.card,
      ),
      child: horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [glyph, const SizedBox(width: 6), text],
            )
          : Column(mainAxisSize: MainAxisSize.min, children: [glyph, text]),
    );
  }
}
