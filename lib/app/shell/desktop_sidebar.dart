import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets.dart';
import '../layout.dart';
import '../theme.dart';
import 'app_bottom_nav.dart';

/// The left rail on laptop and desktop: the mark, the four tabs, and add.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    this.onSelect,
    this.onAdd,
  });

  final int currentIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppLayout.sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.9),
        border: const Border(right: BorderSide(color: AppColors.track)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tab in AppTab.values) ...[
                    _NavItem(
                      tab: tab,
                      isActive: currentIndex == tab.index,
                      onTap: onSelect == null
                          ? null
                          : () => onSelect!(tab.index),
                    ),
                    if (tab != AppTab.values.last) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _AddPlantButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          AppImages.logoIcon,
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Text(
          'RAÍCES',
          style: AppText.eyebrow.copyWith(color: AppColors.body),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.isActive, this.onTap});

  final AppTab tab;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.green : AppColors.body;
    return Semantics(
      button: true,
      selected: isActive,
      label: tab.label,
      child: Material(
        color: isActive ? AppColors.navActive : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: isActive
                  ? null
                  : Border.all(color: AppColors.track),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  tab == AppTab.home ? AppIcons.navHouse : tab.icon,
                  width: tab == AppTab.home ? 19 : tab.iconSize.width,
                  height: tab == AppTab.home ? 19 : tab.iconSize.height,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
                const SizedBox(width: 10),
                Text(
                  tab.label,
                  style: (isActive ? AppText.subtitleBold : AppText.subtitleSemiBold)
                      .copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPlantButton extends StatelessWidget {
  const _AddPlantButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a plant',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: AppColors.terracotta,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            child: SizedBox(
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(AppIcons.navAdd, width: 18, height: 18),
                  const SizedBox(width: 8),
                  Text(
                    'add a plant',
                    style: AppText.title.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
