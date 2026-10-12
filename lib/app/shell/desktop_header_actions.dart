import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../assets.dart';
import '../router.dart';
import 'user_avatar.dart';

/// The language mark and profile photo at the end of a desktop page header.
class DesktopHeaderActions extends ConsumerWidget {
  const DesktopHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarPath = ref.watch(userProfileProvider).value?.avatarPath;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          AppIcons.languageSwitcher,
          width: 40,
          height: 40,
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Profile',
          child: GestureDetector(
            onTap: () => context.pushNamed(ProfileRoute.name),
            child: Container(
              width: 40,
              height: 40,
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
              child: UserAvatar(path: avatarPath, size: 40),
            ),
          ),
        ),
      ],
    );
  }
}
