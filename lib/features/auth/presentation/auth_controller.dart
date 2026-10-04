import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/auth_repository.dart';
import '../domain/auth_mode.dart';

/// Drives the auth card: submission, social sign-in and password reset.
///
/// The state is the progress of the last action, not the session. Success is
/// `AsyncData(null)`; the router notices the new session on its own, so
/// nothing here navigates.
class AuthController extends AsyncNotifier<void> {
  @override
  void build() {}

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Signs in or registers, depending on [mode].
  Future<void> submit({
    required AuthMode mode,
    required String email,
    required String password,
    String? displayName,
    bool rememberMe = true,
  }) async {
    await _run(() async {
      await _repository.setSessionPersistence(remember: rememberMe);
      if (mode.isSignUp) {
        await _repository.createAccount(
          email: email,
          password: password,
          displayName: displayName,
        );
      } else {
        await _repository.signIn(email: email, password: password);
      }
    });
  }

  Future<void> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<void> signInWithApple() => _run(_repository.signInWithApple);

  /// Sends a reset email. Returns true so the caller can confirm it.
  ///
  /// Succeeds even for an address with no account: saying which emails are
  /// registered would hand an attacker a list of your users.
  Future<bool> sendPasswordReset(String email) async {
    await _run(() => _repository.sendPasswordReset(email));
    return !state.hasError;
  }

  /// Clears a failure so the card stops showing it, typically when the user
  /// edits a field or flips between sign-in and sign-up.
  void clearError() {
    if (state.hasError) {
      state = const AsyncData(null);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } on SignInCancelledException {
      // Backing out of a provider sheet is not a failure to report.
      state = const AsyncData(null);
    } on AppException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
