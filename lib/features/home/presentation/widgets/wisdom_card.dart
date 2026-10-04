import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../data/home_template_content.dart';

/// Section 2: the elder's quote on a warm gradient panel.
class WisdomCard extends StatelessWidget {
  const WisdomCard({super.key, this.onSaveNote});

  final VoidCallback? onSaveNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.raised,
        // The design's 151.98° sweep, expressed as start and end alignments.
        gradient: const LinearGradient(
          begin: Alignment(-0.47, -0.88),
          end: Alignment(0.47, 0.88),
          colors: [AppColors.surfaceBlush, AppColors.surfaceClay],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -24,
            right: -16,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      AppIcons.quoteMark,
                      width: 14.167,
                      height: 10,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "GRANDFATHER'S WISDOM",
                        style: AppText.eyebrow.copyWith(
                          color: AppColors.terracotta,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppSizes.pill),
                      ),
                      child: Text(
                        HomeTemplateContent.traditionNumber,
                        style: AppText.label.copyWith(color: AppColors.body),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17.25),
                Text(
                  HomeTemplateContent.wisdomQuote,
                  style: AppText.quote.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 16.75),
                Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        AppImages.elderAvatar,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        HomeTemplateContent.wisdomAuthor,
                        style: AppText.label.copyWith(color: AppColors.body),
                      ),
                    ),
                    GestureDetector(
                      onTap: onSaveNote,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Save note',
                            style: AppText.label.copyWith(
                              color: AppColors.terracotta,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SvgPicture.asset(
                            AppIcons.bookmark,
                            width: 10.667,
                            height: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
