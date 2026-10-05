import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';

/// Section 5: the call to add a plant.
class QuickActionsBanner extends StatelessWidget {
  const QuickActionsBanner({super.key, this.onNewSprout});

  final VoidCallback? onNewSprout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _ActionButton(
          background: AppColors.terracotta,
          icon: AppIcons.actionNewSprout,
          iconSize: const Size(18.333, 16.667),
          label: 'New sprout',
          onTap: onNewSprout,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.background,
    required this.icon,
    required this.iconSize,
    required this.label,
    this.onTap,
  });

  final Color background;
  final String icon;
  final Size iconSize;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  icon,
                  width: iconSize.width,
                  height: iconSize.height,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppText.title.copyWith(color: AppColors.surface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
