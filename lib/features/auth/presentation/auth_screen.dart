import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assets.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_mode.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_canopy.dart';
import 'widgets/auth_card.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/heritage_footer.dart';
import 'widgets/remember_me_row.dart';
import 'widgets/social_sign_in_row.dart';

/// Sign in and sign up, as one card that swaps its copy and grows a name
/// field. Nothing here navigates: the router watches the session and moves on
/// its own once there is one.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  /// How far the card is pulled up over the canopy.
  static const _overlap = 22.0;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late AuthMode _mode = widget.initialMode;
  bool _rememberMe = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggleMode() {
    FocusScope.of(context).unfocus();
    // Drop the previous failure and any validation marks: they described the
    // other form, and carrying them over reads as the toggle having failed.
    _formKey.currentState?.reset();
    ref.read(authControllerProvider.notifier).clearError();
    setState(() => _mode = _mode.opposite);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .submit(
          mode: _mode,
          email: _email.text,
          password: _password.text,
          displayName: _mode.isSignUp ? _name.text.trim() : null,
          rememberMe: _rememberMe,
        );
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (validateEmail(_email.text) != null) {
      _show('Enter your email address first, then tap Forgot.');
      return;
    }

    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);

    if (sent && mounted) {
      _show('If that email has an account, a reset link is on its way.');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppText.body.copyWith(color: AppColors.surface),
          ),
          backgroundColor: AppColors.ink,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final busy = state.isLoading;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthCanopy(),
            Transform.translate(
              offset: const Offset(0, -_overlap),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AuthCard(
                  eyebrow: _mode.eyebrow,
                  title: _mode.title,
                  child: _form(busy, state.error),
                ),
              ),
            ),
            // Transform shifts paint, not layout, so the card still reserves
            // its full height. The design's 48px gap already absorbs the two
            // -22 margins it applies here, so subtract them.
            const HeritageFooter(topPadding: 48 - _overlap * 2),
          ],
        ),
      ),
    );
  }

  Widget _form(bool busy, Object? error) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mode.isSignUp) ...[
              AuthField(
                label: 'Your name',
                controller: _name,
                icon: AppIcons.actionAskElder,
                iconSize: const Size(15.843, 16.667),
                hintText: 'Mateo Solís',
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: validateDisplayName,
                enabled: !busy,
              ),
              const SizedBox(height: 16),
            ],
            AuthField(
              label: 'Email address',
              controller: _email,
              icon: AppIcons.fieldEmail,
              iconSize: const Size(15, 16.667),
              hintText: 'mateo.solis@tierranueva.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: validateEmail,
              enabled: !busy,
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Password',
              controller: _password,
              icon: AppIcons.fieldPassword,
              iconSize: const Size(13.333, 17.5),
              isPassword: true,
              trailingLabel: _mode.isSignUp ? null : 'Forgot?',
              onTrailingLabelTap: busy ? null : _resetPassword,
              textInputAction: TextInputAction.done,
              autofillHints: [
                _mode.isSignUp
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              validator: (value) =>
                  validatePassword(value, isNewAccount: _mode.isSignUp),
              onSubmitted: busy ? null : _submit,
              enabled: !busy,
            ),
            const SizedBox(height: 16),
            if (!_mode.isSignUp)
              RememberMeRow(
                value: _rememberMe,
                onChanged: (value) => setState(() => _rememberMe = value),
              ),
            if (error != null) _ErrorNote(error: error),
            const SizedBox(height: 12),
            AuthPrimaryButton(
              label: _mode.submitLabel,
              onPressed: _submit,
              isLoading: busy,
            ),
            const AuthDivider(label: 'OR CONTINUE WITH'),
            SocialSignInRow(
              enabled: !busy,
              onApple: () =>
                  ref.read(authControllerProvider.notifier).signInWithApple(),
              onGoogle: () =>
                  ref.read(authControllerProvider.notifier).signInWithGoogle(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(child: _modeToggle()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return GestureDetector(
      onTap: _toggleMode,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The prompt yields first at large text scales. The action is the
          // tappable half, so it keeps its full width.
          Flexible(
            child: Text(
              _mode.footerPrompt,
              style: AppText.body.copyWith(color: AppColors.body),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _mode.footerAction,
            style: AppText.titleSemiBold.copyWith(color: AppColors.terracotta),
          ),
        ],
      ),
    );
  }
}

/// The last failure, shown in the form rather than as a snackbar so it stays
/// put while the user fixes it.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? (error as AppException).message
        : 'Something went wrong. Try again.';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceBlush,
          borderRadius: BorderRadius.circular(AppSizes.imageRadius),
        ),
        child: Text(
          message,
          style: AppText.body.copyWith(color: AppColors.terracotta),
        ),
      ),
    );
  }
}
