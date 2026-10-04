import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets.dart';
import '../theme.dart';

/// The four shell destinations, in the order the bar draws them.
///
/// The add button sits between index 1 and 2 visually but is not a
/// destination: it opens a route above the shell.
enum AppTab {
  home(icon: AppIcons.navHome, iconSize: Size(20, 20), label: 'Home'),
  myPlants(
    icon: AppIcons.navMyPlants,
    iconSize: Size(18, 20),
    label: 'My Plants',
  ),
  chores(
    icon: AppIcons.navChores,
    iconSize: Size(20, 15.075),
    label: 'Chores',
  ),
  wisdom(icon: AppIcons.navWisdom, iconSize: Size(22, 16), label: 'Wisdom');

  const AppTab({
    required this.icon,
    required this.iconSize,
    required this.label,
  });

  final String icon;
  final Size iconSize;
  final String label;
}

/// The frosted bottom bar with four destinations around a central add button.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    this.currentIndex = 0,
    this.onSelect,
    this.onAdd,
  });

  final int currentIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: AppShadows.nav),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppSizes.blur,
            sigmaY: AppSizes.blur,
          ),
          child: ColoredBox(
            color: AppColors.canvas.withValues(alpha: 0.95),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: SizedBox(
                    height: AppSizes.navHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          _slot(AppTab.home),
                          _slot(AppTab.myPlants),
                          Expanded(child: _AddButton(onTap: onAdd)),
                          _slot(AppTab.chores),
                          _slot(AppTab.wisdom),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(AppTab tab) => _NavSlot(
    tab: tab,
    isActive: currentIndex == tab.index,
    onTap: onSelect == null ? null : () => onSelect!(tab.index),
  );
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({required this.tab, required this.isActive, this.onTap});

  final AppTab tab;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glyph = SvgPicture.asset(
      tab.icon,
      width: tab.iconSize.width,
      height: tab.iconSize.height,
    );

    return Expanded(
      child: Semantics(
        selected: isActive,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isActive)
                  Container(
                    width: 44,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(AppSizes.pill),
                    ),
                    child: glyph,
                  )
                else
                  SizedBox(height: 28, child: Center(child: glyph)),
                const SizedBox(height: 4),
                Text(
                  tab.label,
                  style: AppText.label.copyWith(
                    color: isActive ? AppColors.green : AppColors.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      // The design lifts the button 4px above the row's centre line.
      child: Transform.translate(
        offset: const Offset(0, -4),
        child: Semantics(
          button: true,
          label: 'Add a plant',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.terracottaBright,
                shape: BoxShape.circle,
                boxShadow: [
                  const BoxShadow(color: AppColors.canvas, spreadRadius: 4),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, 10),
                    blurRadius: 15,
                    spreadRadius: -3,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 6,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: SvgPicture.asset(
                AppIcons.navAdd,
                width: 15.167,
                height: 15.167,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
