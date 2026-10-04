import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../data/home_template_content.dart';

/// Section 1: the date, greeting and next-ritual pill, above the weather strip.
class GreetingSection extends StatelessWidget {
  const GreetingSection({super.key});

  @override
  Widget build(BuildContext context) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        HomeTemplateContent.dateLabel,
                        style: AppText.eyebrow.copyWith(color: AppColors.green),
                      ),
                      const SizedBox(height: 2.5),
                      Text(
                        HomeTemplateContent.greeting,
                        style: AppText.display.copyWith(color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const _RitualPill(),
            ],
          ),
          const SizedBox(height: 8),
          const _WeatherPillStrip(),
        ],
      ),
    );
  }
}

class _RitualPill extends StatelessWidget {
  const _RitualPill();

  @override
  Widget build(BuildContext context) {
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
          SvgPicture.asset(
            AppIcons.morningWatering,
            width: 16.5,
            height: 16.5,
          ),
          const SizedBox(width: 6),
          Text(
            HomeTemplateContent.ritualPillLabel,
            style: AppText.label.copyWith(color: AppColors.greenSoft),
          ),
        ],
      ),
    );
  }
}

class _WeatherPillStrip extends StatelessWidget {
  const _WeatherPillStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceBlush,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(AppIcons.weatherSun, width: 22, height: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      HomeTemplateContent.temperature,
                      style: AppText.metric.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      HomeTemplateContent.sky,
                      style: AppText.labelMedium.copyWith(
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
                Text(
                  HomeTemplateContent.weatherNote,
                  style: AppText.body.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
          const _WeatherChip(
            icon: AppIcons.weatherHumidity,
            iconSize: Size(10.667, 13.333),
            label: HomeTemplateContent.humidity,
          ),
          const SizedBox(width: 12),
          const _WeatherChip(
            icon: AppIcons.weatherUv,
            iconSize: Size(13.333, 10.667),
            label: HomeTemplateContent.uvIndex,
          ),
        ],
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.icon,
    required this.iconSize,
    required this.label,
  });

  final String icon;
  final Size iconSize;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icon,
            width: iconSize.width,
            height: iconSize.height,
          ),
          Text(label, style: AppText.label.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}
