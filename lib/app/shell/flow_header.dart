import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets.dart';
import '../theme.dart';
import 'header_weather.dart';

/// The frosted bar used by the add-plant steps and the plant profile: a back
/// button, a two-line label, and a one-line weather reading.
///
/// [AppHeader] is the tab version of the same bar. This one replaces the logo
/// with a way back and a title, so a pushed screen can say where it sits.
class FlowHeader extends StatelessWidget {
  const FlowHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.onBack,
    this.action = const HeaderWeather(),
  });

  /// The small green line above the title: `STEP 1 OF 3`, `MY PLANTS`.
  final String eyebrow;
  final String title;
  final VoidCallback? onBack;

  /// Sits at the trailing edge. The plant and species bars keep the weather.
  final Widget action;

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
            color: AppColors.canvas.withValues(alpha: 0.95),
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
                      _BackButton(onTap: onBack),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow,
                              style: AppText.eyebrow.copyWith(
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.fieldLabel.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: action,
                        ),
                      ),
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

class _BackButton extends StatelessWidget {
  const _BackButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surfaceBlush,
            shape: BoxShape.circle,
          ),
          child: const _Glyph(AppIcons.flowBack, size: 18),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.asset, {required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset(asset, width: size, height: size);
}

/// The segmented bar under the header on a multi-step flow.
class FlowProgress extends StatelessWidget {
  const FlowProgress({super.key, required this.step, required this.stepCount});

  /// One-based, so `step: 2` fills the first two segments.
  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 1; index <= stepCount; index++) ...[
          if (index > 1) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: index <= step ? AppColors.terracotta : AppColors.border,
                borderRadius: BorderRadius.circular(AppSizes.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
