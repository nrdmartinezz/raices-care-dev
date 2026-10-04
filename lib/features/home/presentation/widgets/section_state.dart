import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';

/// A quiet card standing in for a section that is empty or has failed.
class SectionMessage extends StatelessWidget {
  const SectionMessage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.title.copyWith(color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(body, style: AppText.body.copyWith(color: AppColors.body)),
        ],
      ),
    );
  }
}

/// Placeholder rows shown while a section's stream delivers its first value.
class SectionSkeleton extends StatelessWidget {
  const SectionSkeleton({super.key, this.rows = 2, this.height = 74});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
          ),
          if (i != rows - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// A sentence the user can act on, rather than a Firebase error code.
String describeSectionError(Object error) => switch (error) {
  UnauthenticatedException() => 'Sign in to see your garden.',
  PermissionDeniedException() => 'This garden is not available to you.',
  NetworkException() => 'No connection. This will fill in once you are back '
      'online.',
  AppException(:final message) => message,
  _ => 'Something went wrong. Pull to try again.',
};
