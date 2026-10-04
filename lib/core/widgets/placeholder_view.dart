import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';

/// Stand-in body for a screen that is routed but not built yet.
///
/// Deliberately styled rather than blank, so an unfinished tab still looks
/// like part of the app and the shell's spacing can be judged honestly.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.bullets = const [],
  });

  final String icon;
  final Size iconSize;
  final String eyebrow;
  final String title;
  final String description;

  /// What this screen will eventually do. Keeps the placeholder useful as a
  /// note to whoever builds it.
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surfaceBlush,
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(
            icon,
            width: iconSize.width * 1.4,
            height: iconSize.height * 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(eyebrow, style: AppText.eyebrow.copyWith(color: AppColors.green)),
        const SizedBox(height: 2.5),
        Text(title, style: AppText.display.copyWith(color: AppColors.ink)),
        const SizedBox(height: 8),
        Text(description, style: AppText.body.copyWith(color: AppColors.body)),
        if (bullets.isNotEmpty) ...[
          const SizedBox(height: AppSizes.sectionGap),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coming here',
                  style: AppText.label.copyWith(color: AppColors.terracotta),
                ),
                const SizedBox(height: 8),
                for (final bullet in bullets) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.mint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bullet,
                          style: AppText.body.copyWith(color: AppColors.body),
                        ),
                      ),
                    ],
                  ),
                  if (bullet != bullets.last) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
