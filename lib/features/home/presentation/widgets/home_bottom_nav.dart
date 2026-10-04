import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';

/// The frosted bottom bar with four destinations around a central add button.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({super.key, this.currentIndex = 0, this.onAdd});

  final int currentIndex;
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
                          _NavSlot(
                            icon: AppIcons.navHome,
                            iconSize: const Size(20, 20),
                            label: 'Home',
                            isActive: currentIndex == 0,
                          ),
                          _NavSlot(
                            icon: AppIcons.navMyPlants,
                            iconSize: const Size(18, 20),
                            label: 'My Plants',
                            isActive: currentIndex == 1,
                          ),
                          Expanded(child: _AddButton(onTap: onAdd)),
                          _NavSlot(
                            icon: AppIcons.navChores,
                            iconSize: const Size(20, 15.075),
                            label: 'Chores',
                            isActive: currentIndex == 2,
                          ),
                          _NavSlot(
                            icon: AppIcons.navWisdom,
                            iconSize: const Size(22, 16),
                            label: 'Wisdom',
                            isActive: currentIndex == 3,
                          ),
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
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.isActive,
  });

  final String icon;
  final Size iconSize;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final glyph = SvgPicture.asset(
      icon,
      width: iconSize.width,
      height: iconSize.height,
    );

    return Expanded(
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
              label,
              style: AppText.label.copyWith(
                color: isActive ? AppColors.green : AppColors.body,
              ),
            ),
          ],
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
    );
  }
}
