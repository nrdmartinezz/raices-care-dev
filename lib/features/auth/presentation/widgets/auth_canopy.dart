import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import 'auth_logo.dart';

/// The deep forest band behind the auth card: language pill, then the logo.
///
/// The card overlaps its lower edge, so the canopy pads itself generously at
/// the bottom and the caller pulls the card up over it.
class AuthCanopy extends StatelessWidget {
  const AuthCanopy({super.key, this.onLanguage});

  final VoidCallback? onLanguage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.canopyDeep, AppColors.canopySage],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                16,
                AppSizes.screenPadding,
                0,
              ),
              child: Row(
                children: [_LanguagePill(onTap: onLanguage), const Spacer()],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: AuthLogo(),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }
}

/// ES / EN. Inert — the app has no localization yet.
class _LanguagePill extends StatelessWidget {
  const _LanguagePill({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            color: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ES',
                  style: AppText.label.copyWith(color: AppColors.surface),
                ),
                const SizedBox(width: 4),
                Text(
                  '/',
                  style: AppText.input.copyWith(
                    height: 21 / 14,
                    color: AppColors.canvas.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'EN',
                  style: AppText.label.copyWith(color: AppColors.accentAmber),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
