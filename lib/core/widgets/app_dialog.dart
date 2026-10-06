import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// The dim layer behind the centered account and photo dialogs.
const appDialogBarrier = Color(0x73231916);

/// A centered card: blush icon, Newsreader title, short explanation, actions.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  final Widget icon;
  final String title;
  final String message;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2C221E).withValues(alpha: 0.08),
                offset: const Offset(0, 8),
                blurRadius: 24,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 16),
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The outline and terracotta buttons used inside [AppDialog].
class AppDialogButton extends StatelessWidget {
  const AppDialogButton({
    super.key,
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: filled
            ? [
                BoxShadow(
                  color: const Color(0xFF2C221E).withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Material(
        color: filled ? AppColors.terracotta : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: filled
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: AppText.subtitleBold.copyWith(
                  color: filled ? AppColors.surface : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 48px blush circle behind a small glyph.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({super.key, required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceBlush,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(icon),
    );
  }
}
