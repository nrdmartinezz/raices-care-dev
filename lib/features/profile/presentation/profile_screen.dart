import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/assets.dart';
import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/shell/user_avatar.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../onboarding/data/avatar_repository.dart';
import '../../photos/presentation/photo_picker.dart';
import 'account_widgets.dart';

/// Who is signed in: name, contact details, and the way into settings.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _uploading = false;
  String? _photoError;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    return ColoredBox(
      color: AppColors.canvas,
      child: profile.when(
        data: (user) => user == null
            ? const SizedBox.shrink()
            : _ProfileBody(
                user: user,
                uploading: _uploading,
                photoError: _photoError,
                onEditPhoto: () => _changePhoto(user),
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.terracotta),
        ),
        error: (error, stackTrace) => _ProfileFailure(error: error),
      ),
    );
  }

  Future<void> _changePhoto(AppUser user) async {
    setState(() => _photoError = null);
    try {
      final photo = await pickGardenPhoto(context, crop: PhotoCrop.square);
      if (photo == null || !mounted) {
        return;
      }
      setState(() => _uploading = true);
      final path = await ref
          .read(avatarRepositoryProvider)
          .uploadAvatar(bytes: photo.bytes, contentType: photo.contentType);
      await ref
          .read(authRepositoryProvider)
          .updateProfile(user.copyWith(avatarPath: path));
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _photoError = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.user,
    required this.uploading,
    required this.photoError,
    required this.onEditPhoto,
  });

  final AppUser user;
  final bool uploading;
  final String? photoError;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final name = _displayName(user);
    return ShellScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your profile', style: accountPageTitle),
          const SizedBox(height: 6),
          Text(
            'A little about you. A place for your plants.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _SummaryCard(
            name: name,
            avatarPath: user.avatarPath,
            uploading: uploading,
            onEditPhoto: onEditPhoto,
          ),
          if (photoError != null) ...[
            const SizedBox(height: 8),
            AccountMessage(message: photoError!, isError: true),
          ],
          const SizedBox(height: AppSizes.sectionGap),
          Text(
            'Personal information',
            style: AppText.title.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          _DetailsCard(user: user),
          const SizedBox(height: AppSizes.sectionGap),
          const _SettingsEntry(),
          const SizedBox(height: 10),
          Text(
            'You can add your email and phone in Settings.',
            style: AppText.caption.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          const _SupportEntry(),
          const SizedBox(height: 10),
          Text(
            'Opens a separate support screen with bug reporting and Ko-fi '
            'support options.',
            style: AppText.caption.copyWith(color: AppColors.body),
          ),
        ],
      ),
    );
  }
}

String _displayName(AppUser user) {
  final name = user.displayName?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  return 'Your account';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.name,
    required this.avatarPath,
    required this.uploading,
    required this.onEditPhoto,
  });

  final String name;
  final String? avatarPath;
  final bool uploading;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _EditableAvatar(
            path: avatarPath,
            uploading: uploading,
            onEdit: onEditPhoto,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR RAÍCES ACCOUNT',
                  style: AppText.eyebrow.copyWith(color: AppColors.green),
                ),
                const SizedBox(height: 5),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.path,
    required this.uploading,
    required this.onEdit,
  });

  final String? path;
  final bool uploading;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C221E).withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: UserAvatar(path: path, size: 72),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: 'Edit photo',
              child: GestureDetector(
                onTap: uploading ? null : onEdit,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2C221E).withValues(alpha: 0.08),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: uploading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.green,
                          ),
                        )
                      : SvgPicture.asset(AppIcons.accountPencil),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _Detail(
        icon: AppIcons.accountUser,
        label: 'NAME',
        value: _hasContact(user.displayName)
            ? user.displayName!.trim()
            : 'Not added yet',
        filled: _hasContact(user.displayName),
      ),
      _Detail(
        icon: AppIcons.accountMail,
        label: 'EMAIL',
        value: _contact(user.email),
        filled: _hasContact(user.email),
      ),
      _Detail(
        icon: AppIcons.accountPhone,
        label: 'PHONE',
        value: _contact(user.phoneNumber),
        filled: _hasContact(user.phoneNumber),
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: accountCardDecoration(),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            _DetailRow(
              detail: rows[index],
              showDivider: index != rows.length - 1,
            ),
        ],
      ),
    );
  }
}

bool _hasContact(String? value) {
  final text = value?.trim();
  return text != null && text.isNotEmpty;
}

String _contact(String? value) =>
    _hasContact(value) ? value!.trim() : 'Not added yet';

class _Detail {
  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
    required this.filled,
  });

  final String icon;
  final String label;
  final String value;
  final bool filled;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail, required this.showDivider});

  final _Detail detail;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          AccountIconTile(icon: detail.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.label,
                  style: AppText.eyebrow.copyWith(color: AppColors.body),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: detail.filled
                      ? AppText.subtitleBold.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        )
                      : AppText.bodyLarge.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Account settings',
      child: GestureDetector(
        onTap: () => context.pushNamed(AccountSettingsRoute.name),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: accountCardDecoration(bordered: true),
          child: Row(
            children: [
              const AccountIconTile(icon: AppIcons.accountSettings, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account settings',
                      style: AppText.subtitleBold.copyWith(
                        color: AppColors.terracotta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update email, phone or password',
                      style: AppText.body.copyWith(color: AppColors.body),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(AppIcons.accountChevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportEntry extends StatelessWidget {
  const _SupportEntry();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Support',
      child: GestureDetector(
        onTap: () => context.pushNamed(SupportRoute.name),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: accountCardDecoration(bordered: true),
          child: Row(
            children: [
              const AccountIconTile(icon: AppIcons.supportHelp, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support',
                      style: AppText.subtitleBold.copyWith(
                        color: AppColors.terracotta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Report a bug or support the app on Ko-fi',
                      style: AppText.body.copyWith(color: AppColors.body),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(AppIcons.accountChevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFailure extends StatelessWidget {
  const _ProfileFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      AppException(:final message) => message,
      _ => 'Your profile could not be loaded.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.bodyLarge.copyWith(color: AppColors.body),
        ),
      ),
    );
  }
}
