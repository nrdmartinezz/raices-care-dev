import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/settings/data/user_settings_repository.dart';
import '../theme.dart';

/// Who is signed in, and the way out.
///
/// A placeholder for a real account screen; it exists so the session can be
/// ended, which the auth flow is otherwise impossible to re-enter.
Future<void> showAccountSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          20,
          AppSizes.screenPadding,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SIGNED IN AS',
              style: AppText.eyebrow.copyWith(color: AppColors.terracotta),
            ),
            const SizedBox(height: 2.5),
            Consumer(
              builder: (context, ref, child) {
                final profile = ref.watch(userProfileProvider).value;
                return Text(
                  profile?.displayName ?? profile?.email ?? 'Your account',
                  style: AppText.cardTitle.copyWith(color: AppColors.ink),
                );
              },
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _signOut(ref);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.terracotta,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                'Sign out',
                style: AppText.title.copyWith(color: AppColors.terracotta),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _signOut(WidgetRef ref) async {
  // Drop this device's push token first. Leaving it behind would send the
  // next person to sign in on this phone the previous user's reminders.
  try {
    await ref.read(userSettingsRepositoryProvider).removeCurrentDeviceToken();
  } on Object {
    // Best effort: a stale token is better than being unable to sign out.
  }
  await ref.read(authRepositoryProvider).signOut();
}
