import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';

/// The terracotta call to action at the foot of the form.
///
/// Keeps its height while loading, so the card does not jolt on submit.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.imageRadius),
        boxShadow: AppShadows.cta,
      ),
      child: Material(
        color: enabled
            ? AppColors.terracotta
            : AppColors.terracotta.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppSizes.imageRadius),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppSizes.imageRadius),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppText.title.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SvgPicture.asset(
                          AppIcons.ctaArrow,
                          width: 13.333,
                          height: 13.333,
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
