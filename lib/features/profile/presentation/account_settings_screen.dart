import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/assets.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_validators.dart';
import '../data/account_gateway.dart';
import 'account_confirm_dialog.dart';
import 'account_widgets.dart';

/// Email, phone, and password, plus the way out of the session.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _phoneForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  var _emailBusy = false;
  var _phoneBusy = false;
  var _passwordBusy = false;
  var _deleteBusy = false;
  _Notice? _emailNotice;
  _Notice? _phoneNotice;
  _Notice? _passwordNotice;
  _Notice? _dangerNotice;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final gateway = ref.watch(accountGatewayProvider);
    return ColoredBox(
      color: AppColors.canvas,
      child: profile.when(
        data: (user) => user == null
            ? const SizedBox.shrink()
            : _SettingsBody(
                user: user,
                gateway: gateway,
                emailForm: _emailForm,
                phoneForm: _phoneForm,
                passwordForm: _passwordForm,
                email: _email,
                phone: _phone,
                currentPassword: _currentPassword,
                newPassword: _newPassword,
                confirmPassword: _confirmPassword,
                emailBusy: _emailBusy,
                phoneBusy: _phoneBusy,
                passwordBusy: _passwordBusy,
                emailNotice: _emailNotice,
                phoneNotice: _phoneNotice,
                passwordNotice: _passwordNotice,
                dangerNotice: _dangerNotice,
                deleteBusy: _deleteBusy,
                onUpdateEmail: () => _updateEmail(user),
                onUpdatePhone: () => _updatePhone(user),
                onUpdatePassword: _updatePassword,
                onSignOut: _signOut,
                onDeleteAccount: _deleteAccount,
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.terracotta),
        ),
        error: (error, stackTrace) => Center(
          child: Text(
            error is AppException
                ? error.message
                : 'Settings could not be loaded.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
        ),
      ),
    );
  }

  Future<void> _updateEmail(AppUser user) async {
    if (!(_emailForm.currentState?.validate() ?? false)) {
      return;
    }
    final email = _email.text.trim();
    final current = user.email?.trim();
    if (current != null && current.toLowerCase() == email.toLowerCase()) {
      setState(() {
        _emailNotice = const _Notice(
          'That is already your email.',
          isError: true,
        );
      });
      return;
    }

    setState(() {
      _emailBusy = true;
      _emailNotice = null;
    });
    try {
      final sent = await _sendEmailUpdate(email);
      if (!mounted || !sent) {
        return;
      }
      _email.clear();
      setState(() {
        _emailNotice = const _Notice(
          'Check your inbox to confirm the new address. '
          'It will update once you confirm.',
        );
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _emailNotice = _Notice(error.message, isError: true));
      }
    } finally {
      if (mounted) {
        setState(() => _emailBusy = false);
      }
    }
  }

  /// False when the gardener dismisses the password prompt.
  Future<bool> _sendEmailUpdate(String email) async {
    final gateway = ref.read(accountGatewayProvider);
    try {
      await gateway.requestEmailUpdate(email);
      return true;
    } on RecentLoginRequiredException {
      if (!mounted) {
        return false;
      }
      final password = await _askCurrentPassword(context);
      if (password == null || password.isEmpty) {
        return false;
      }
      await gateway.requestEmailUpdate(email, currentPassword: password);
      return true;
    }
  }

  Future<void> _updatePhone(AppUser user) async {
    if (!(_phoneForm.currentState?.validate() ?? false)) {
      return;
    }
    final phone = _phone.text.trim();
    if (user.phoneNumber?.trim() == phone) {
      setState(() {
        _phoneNotice = const _Notice(
          'That is already your phone number.',
          isError: true,
        );
      });
      return;
    }

    setState(() {
      _phoneBusy = true;
      _phoneNotice = null;
    });
    try {
      await ref.read(accountGatewayProvider).updatePhone(user, phone);
      if (!mounted) {
        return;
      }
      _phone.clear();
      setState(() {
        _phoneNotice = const _Notice('Phone number updated.');
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _phoneNotice = _Notice(error.message, isError: true));
      }
    } finally {
      if (mounted) {
        setState(() => _phoneBusy = false);
      }
    }
  }

  Future<void> _updatePassword() async {
    if (!(_passwordForm.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _passwordBusy = true;
      _passwordNotice = null;
    });
    try {
      await ref
          .read(accountGatewayProvider)
          .updatePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) {
        return;
      }
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() {
        _passwordNotice = const _Notice('Password updated.');
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _passwordNotice = _Notice(error.message, isError: true));
      }
    } finally {
      if (mounted) {
        setState(() => _passwordBusy = false);
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showAccountConfirmDialog(
      context,
      icon: SvgPicture.asset(AppIcons.accountSignOutBadge),
      title: 'Sign out?',
      message:
          'You will be logged out of this device. You can sign back in '
          'anytime with your email and password.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(accountGatewayProvider).signOut();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _dangerNotice = _Notice(error.message, isError: true));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showAccountConfirmDialog(
      context,
      icon: const AppIconBadge(icon: AppIcons.accountAlert),
      title: 'Delete account?',
      message: 'Are you sure you want to delete your account?',
      confirmLabel: 'Delete account',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _deleteBusy = true;
      _dangerNotice = null;
    });
    try {
      await _deleteConfirmedAccount();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _dangerNotice = _Notice(error.message, isError: true));
      }
    } finally {
      if (mounted) {
        setState(() => _deleteBusy = false);
      }
    }
  }

  Future<void> _deleteConfirmedAccount() async {
    final gateway = ref.read(accountGatewayProvider);
    try {
      await gateway.deleteAccount();
    } on RecentLoginRequiredException {
      if (!gateway.canChangePassword) {
        throw const RecentLoginRequiredException(
          'Sign in again before deleting this account.',
        );
      }
      if (!mounted) {
        return;
      }
      final password = await _askCurrentPassword(context);
      if (password == null || password.isEmpty) {
        return;
      }
      await gateway.deleteAccount(currentPassword: password);
    }
  }
}

class _Notice {
  const _Notice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.user,
    required this.gateway,
    required this.emailForm,
    required this.phoneForm,
    required this.passwordForm,
    required this.email,
    required this.phone,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
    required this.emailBusy,
    required this.phoneBusy,
    required this.passwordBusy,
    required this.emailNotice,
    required this.phoneNotice,
    required this.passwordNotice,
    required this.dangerNotice,
    required this.deleteBusy,
    required this.onUpdateEmail,
    required this.onUpdatePhone,
    required this.onUpdatePassword,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final AppUser user;
  final AccountGateway gateway;
  final GlobalKey<FormState> emailForm;
  final GlobalKey<FormState> phoneForm;
  final GlobalKey<FormState> passwordForm;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController currentPassword;
  final TextEditingController newPassword;
  final TextEditingController confirmPassword;
  final bool emailBusy;
  final bool phoneBusy;
  final bool passwordBusy;
  final _Notice? emailNotice;
  final _Notice? phoneNotice;
  final _Notice? passwordNotice;
  final _Notice? dangerNotice;
  final bool deleteBusy;
  final VoidCallback onUpdateEmail;
  final VoidCallback onUpdatePhone;
  final VoidCallback onUpdatePassword;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final email = user.email?.trim();
    final phone = user.phoneNumber?.trim();
    return ShellScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account settings', style: accountPageTitle),
          const SizedBox(height: 6),
          Text(
            'Keep your contact details up to date and your account secure.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _UpdateCard(
            icon: AppIcons.accountMail,
            title: 'Email address',
            status: email == null || email.isEmpty
                ? 'No email added yet'
                : email,
            formKey: emailForm,
            notice: emailNotice,
            buttonLabel: 'Update email',
            busy: emailBusy,
            onPressed: onUpdateEmail,
            fields: [
              AccountField(
                label: 'EMAIL',
                hint: 'Enter your email address',
                controller: this.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                enabled: !emailBusy,
                validator: validateEmail,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _UpdateCard(
            icon: AppIcons.accountPhone,
            title: 'Phone number',
            status: phone == null || phone.isEmpty
                ? 'No phone added yet'
                : phone,
            formKey: phoneForm,
            notice: phoneNotice,
            buttonLabel: 'Update phone',
            busy: phoneBusy,
            onPressed: onUpdatePhone,
            fields: [
              AccountField(
                label: 'PHONE',
                hint: 'Enter your phone number',
                controller: this.phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                enabled: !phoneBusy,
                validator: validatePhone,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          if (gateway.canChangePassword)
            _UpdateCard(
              icon: AppIcons.accountLock,
              title: 'Change password',
              status: newPasswordHint,
              formKey: passwordForm,
              notice: passwordNotice,
              buttonLabel: 'Update password',
              busy: passwordBusy,
              onPressed: onUpdatePassword,
              fields: [
                AccountField(
                  label: 'CURRENT PASSWORD',
                  hint: 'Enter current password',
                  controller: currentPassword,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  enabled: !passwordBusy,
                  validator: (value) =>
                      validatePassword(value, isNewAccount: false),
                ),
                AccountField(
                  label: 'NEW PASSWORD',
                  hint: 'Enter new password',
                  controller: newPassword,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !passwordBusy,
                  validator: (value) =>
                      validatePassword(value, isNewAccount: true),
                ),
                AccountField(
                  label: 'CONFIRM NEW PASSWORD',
                  hint: 'Re-enter new password',
                  controller: confirmPassword,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !passwordBusy,
                  validator: (value) {
                    final passwordError = validatePassword(
                      value,
                      isNewAccount: true,
                    );
                    if (passwordError != null) {
                      return passwordError;
                    }
                    if (value != newPassword.text) {
                      return 'Those passwords do not match.';
                    }
                    return null;
                  },
                ),
              ],
            )
          else
            _ExternalSignInNote(
              provider:
                  gateway.externalProviderLabel ?? 'your sign-in provider',
            ),
          const SizedBox(height: AppSizes.sectionGap),
          _DangerZone(
            onSignOut: onSignOut,
            onDeleteAccount: onDeleteAccount,
            busy: deleteBusy,
            notice: dangerNotice,
          ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.busy,
    required this.notice,
  });

  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;
  final bool busy;
  final _Notice? notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: accountCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccountIconTile(icon: AppIcons.accountAlert, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danger zone',
                      style: AppText.title.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sign out or delete your account.',
                      style: AppText.caption.copyWith(
                        color: AppColors.body,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OutlineAction(label: 'Sign out', onPressed: busy ? null : onSignOut),
          const SizedBox(height: 10),
          AccountUpdateButton(
            label: 'Delete account',
            onPressed: busy ? null : onDeleteAccount,
            busy: busy,
          ),
          if (notice != null) ...[
            const SizedBox(height: 10),
            AccountMessage(message: notice!.message, isError: notice!.isError),
          ],
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: AppText.subtitleBold.copyWith(color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.formKey,
    required this.fields,
    required this.buttonLabel,
    required this.onPressed,
    required this.busy,
    this.notice,
  });

  final String icon;
  final String title;
  final String status;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool busy;
  final _Notice? notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: accountCardDecoration(),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AccountIconTile(icon: icon, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.title.copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status,
                        style: AppText.caption.copyWith(color: AppColors.body),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < fields.length; index++) ...[
              if (index > 0) const SizedBox(height: 16),
              fields[index],
            ],
            const SizedBox(height: 16),
            AccountUpdateButton(
              label: buttonLabel,
              onPressed: onPressed,
              busy: busy,
            ),
            if (notice != null) ...[
              const SizedBox(height: 10),
              AccountMessage(
                message: notice!.message,
                isError: notice!.isError,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExternalSignInNote extends StatelessWidget {
  const _ExternalSignInNote({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: accountCardDecoration(),
      child: Row(
        children: [
          const AccountIconTile(icon: AppIcons.accountLock, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change password',
                  style: AppText.title.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  'You sign in with $provider, so this account has no password to change.',
                  style: AppText.caption.copyWith(color: AppColors.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askCurrentPassword(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _PasswordDialog(),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Confirm it is you',
        style: AppText.title.copyWith(color: AppColors.ink),
      ),
      content: AccountField(
        label: 'CURRENT PASSWORD',
        hint: 'Enter current password',
        controller: _password,
        obscure: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppText.subtitleBold.copyWith(color: AppColors.body),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_password.text),
          child: Text(
            'Continue',
            style: AppText.subtitleBold.copyWith(color: AppColors.terracotta),
          ),
        ),
      ],
    );
  }
}
