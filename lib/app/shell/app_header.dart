import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets.dart';
import '../theme.dart';

/// The frosted top bar: logo on the left, language switcher and avatar right.
///
/// Lives in the shell, so it stays put as tabs change.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.onLanguage, this.onProfile});

  final VoidCallback? onLanguage;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: AppShadows.header),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppSizes.blur,
            sigmaY: AppSizes.blur,
          ),
          child: ColoredBox(
            color: AppColors.canvas.withValues(alpha: 0.9),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: AppSizes.headerHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  child: Row(
                    children: [
                      const _Logo(),
                      const Spacer(),
                      _LanguageSwitcher(onTap: onLanguage),
                      const SizedBox(width: 6),
                      _ProfileButton(onTap: onProfile),
                    ],
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      // The design crops the mark to 141.18% of the slot to trim its margin.
      child: ClipRect(
        child: Transform.scale(
          scale: 1.4118,
          child: Image.asset(AppImages.logo, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(AppIcons.language, width: 14, height: 17.5),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: AppColors.canvas, spreadRadius: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C221E).withValues(alpha: 0.12),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(AppImages.profile, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}
