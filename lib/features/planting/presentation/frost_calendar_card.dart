import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/planting_repository.dart';
import '../domain/sowing_calendar.dart';

class FrostCalendarCard extends StatelessWidget {
  const FrostCalendarCard({required this.frost, super.key});

  final GardenFrost frost;

  @override
  Widget build(BuildContext context) {
    final zone = switch (frost) {
      GardenFrostReady(:final zone) => zone,
      GardenFrostUnavailable(:final zone) => zone,
      GardenFrostMissingZip() => null,
    };
    final message = switch (frost) {
      GardenFrostMissingZip() =>
        'Finish garden setup to see the frost calendar.',
      GardenFrostUnavailable() =>
        'The frost calendar is not available for this garden.',
      GardenFrostReady() => null,
    };
    final ready = frost is GardenFrostReady ? frost as GardenFrostReady : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone == null || zone.isEmpty
                ? 'YOUR GARDEN'
                : 'ZONE ${zone.toUpperCase()}',
            style: AppText.eyebrow.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 8),
          if (ready != null) ...[
            _FrostLine(
              label: 'Last spring freeze',
              value: formatPlantingDay(ready.frost.lastSpringFrost),
            ),
            const SizedBox(height: 6),
            _FrostLine(
              label: 'First fall freeze',
              value: formatPlantingDay(ready.frost.firstFallFrost),
            ),
            const SizedBox(height: 8),
            Text(
              ready.frost.label,
              style: AppText.caption.copyWith(color: AppColors.muted),
            ),
          ] else
            Text(
              message ?? 'The frost calendar is not available for this garden.',
              style: AppText.body.copyWith(color: AppColors.body),
            ),
        ],
      ),
    );
  }
}

class _FrostLine extends StatelessWidget {
  const _FrostLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        ),
        Text(value, style: AppText.title.copyWith(color: AppColors.ink)),
      ],
    );
  }
}

class SeasonPill extends StatelessWidget {
  const SeasonPill({required this.inSeason, super.key});

  final bool inSeason;

  @override
  Widget build(BuildContext context) {
    final background = inSeason ? AppColors.mintSoft : AppColors.surfaceClay;
    final foreground = inSeason ? AppColors.green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.pill),
      ),
      child: Text(
        inSeason ? 'In season' : 'Off season',
        style: AppText.label.copyWith(color: foreground),
      ),
    );
  }
}
