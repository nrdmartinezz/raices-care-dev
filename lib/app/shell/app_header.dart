import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../assets.dart';
import '../theme.dart';
import 'header_bell.dart';
import 'header_weather.dart';
import 'user_avatar.dart';

/// The frosted top bar: the mark on the left, the avatar on the right.
///
/// Lives in the shell, so it stays put as tabs change. Home is the mark and
/// the avatar. Every other tab keeps the mark and centers a one-line weather
/// reading between them.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.onProfile,
    this.showWeather = false,
    this.showBell = false,
  });

  final VoidCallback? onProfile;

  /// When true, a one-line weather reading sits in the center of the bar.
  final bool showWeather;

  /// When true, the notifications bell sits just before the avatar.
  final bool showBell;

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
                  child: showWeather
                      ? _WeatherBar(onProfile: onProfile, showBell: showBell)
                      : _MarkBar(onProfile: onProfile, showBell: showBell),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkBar extends StatelessWidget {
  const _MarkBar({this.onProfile, this.showBell = false});

  final VoidCallback? onProfile;
  final bool showBell;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Logo(),
        const Spacer(),
        if (showBell) ...[const HeaderBell(), const SizedBox(width: 6)],
        _ProfileButton(onTap: onProfile),
      ],
    );
  }
}

/// Logo on the left, avatar on the right, weather centered on the bar.
///
/// The reading is inset so a long place name ellipsizes before it meets the
/// mark or the profile control. The wide inset matches the room the name
/// beside the avatar is allowed to take.
class _WeatherBar extends StatelessWidget {
  const _WeatherBar({this.onProfile, this.showBell = false});

  final VoidCallback? onProfile;
  final bool showBell;

  static const _inset = 52.0;
  static const _wideInset = 232.0;

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= _ProfileButton._desktopWidth;
    final inset = wide ? _wideInset : _inset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWeather = (constraints.maxWidth - inset * 2).clamp(
          0.0,
          double.infinity,
        );
        return Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWeather),
              child: const HeaderWeather(textAlign: TextAlign.center),
            ),
            Row(
              children: [
                const _Logo(),
                const Spacer(),
                if (showBell) ...[const HeaderBell(), const SizedBox(width: 6)],
                _ProfileButton(onTap: onProfile),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(AppImages.logoIcon, height: 52, fit: BoxFit.contain);
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

    return Semantics(
      button: onTap != null,
      label: 'Profile',
      child: GestureDetector(
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
                  child: UserAvatar(path: avatarPath),
                ),
              ),
            ),
          ],
        ),
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
