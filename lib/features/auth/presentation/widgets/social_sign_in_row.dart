import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';

/// A hairline rule either side of a centred caption.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: _Rule()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: AppText.dividerLabel.copyWith(color: AppColors.muted),
            ),
          ),
          const Expanded(child: _Rule()),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.surfaceClay, child: SizedBox(height: 1));
}

/// Apple and Google, side by side.
///
/// The design has a third magic-link button; it was dropped, so the two that
/// remain share the row evenly rather than leaving a gap where it sat.
class SocialSignInRow extends StatelessWidget {
  const SocialSignInRow({
    super.key,
    this.onApple,
    this.onGoogle,
    this.enabled = true,
  });

  final VoidCallback? onApple;
  final VoidCallback? onGoogle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            icon: AppIcons.socialApple,
            label: 'Continue with Apple',
            onTap: enabled ? onApple : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SocialButton(
            icon: AppIcons.socialGoogle,
            label: 'Continue with Google',
            onTap: enabled ? onGoogle : null,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label, this.onTap});

  final String icon;

  /// Not drawn — the design shows the mark alone — but screen readers need it.
  final String label;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surfaceBlush,
        borderRadius: BorderRadius.circular(AppSizes.imageRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.imageRadius),
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: SizedBox(
              height: 48,
              child: Center(
                child: SvgPicture.asset(icon, width: 20, height: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
