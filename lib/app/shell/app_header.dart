import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/onboarding/data/avatar_repository.dart';
import '../assets.dart';
import '../theme.dart';

/// The frosted top bar: logo on the left, avatar on the right.
///
/// Lives in the shell, so it stays put as tabs change.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.onProfile});

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

class _ProfileButton extends ConsumerWidget {
  const _ProfileButton({this.onTap});

  final VoidCallback? onTap;

  /// Wide enough that the name sits beside the icon instead of crowding a phone.
  static const _desktopWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final avatarPath = profile?.avatarPath;
    final name = _profileLabel(profile);
    final showName =
        name != null && MediaQuery.sizeOf(context).width >= _desktopWidth;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showName) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.fieldLabel.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
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
                  child: avatarPath == null
                      ? Image.asset(AppImages.profile, fit: BoxFit.cover)
                      : _StoredAvatar(path: avatarPath),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _profileLabel(AppUser? profile) {
  final name = profile?.displayName?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final email = profile?.email?.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }
  return null;
}

class _StoredAvatar extends ConsumerWidget {
  const _StoredAvatar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(avatarUrlProvider(path));
    return url.when(
      data: (value) => Image.network(
        value,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset(AppImages.profile, fit: BoxFit.cover),
      ),
      loading: () => Image.asset(AppImages.profile, fit: BoxFit.cover),
      error: (error, stackTrace) =>
          Image.asset(AppImages.profile, fit: BoxFit.cover),
    );
  }
}
