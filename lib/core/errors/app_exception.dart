import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Failures the UI is expected to handle.
///
/// Repositories translate Firebase's platform exceptions into these, so no
/// feature code has to know about `FirebaseException` codes.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// Not signed in, or the session expired.
class UnauthenticatedException extends AppException {
  const UnauthenticatedException([
    super.message = 'Sign in to continue.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// Signed in, but the security rules refused the operation.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = 'You do not have access to that.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

class NotFoundException extends AppException {
  const NotFoundException([
    super.message = 'That record no longer exists.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'No connection. Changes will sync when you are back online.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// A rate limit or quota, including the plant catalog's 60 requests a minute.
class RateLimitedException extends AppException {
  const RateLimitedException([
    super.message = 'Too many requests just now. Try again shortly.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// The email is registered, but to a different sign-in method.
///
/// Firebase keeps one account per email address, so signing in with Google
/// after registering with a password is refused rather than merged.
class AccountExistsException extends AppException {
  const AccountExistsException([
    super.message =
        'You already have an account with this email. '
        'Sign in with the method you used before.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// The sign-in method is not enabled on the Firebase project.
///
/// Expected until Google and Apple are configured in the console. Separate
/// from a real failure so the UI can say so plainly instead of blaming the
/// user's credentials.
class SignInUnavailableException extends AppException {
  const SignInUnavailableException([
    super.message = 'That sign-in method is not set up yet.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// The user backed out of a social sign-in sheet.
///
/// Not an error to show: callers are expected to swallow it.
class SignInCancelledException extends AppException {
  const SignInCancelledException([
    super.message = 'Sign-in cancelled.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// The data did not match what the model expected.
class MalformedDataException extends AppException {
  const MalformedDataException(super.message, {super.cause, super.stackTrace});
}

class UnexpectedException extends AppException {
  const UnexpectedException([
    super.message = 'Something went wrong.',
    Object? cause,
    StackTrace? stackTrace,
  ]) : super(cause: cause, stackTrace: stackTrace);
}

/// The 2023 ZIP hardiness listing could not answer.
///
/// The gardener stays on the ZIP step. A zone is never invented instead.
class ZoneLookupException extends AppException {
  const ZoneLookupException(super.message, {super.cause, super.stackTrace});
}

/// Normalizes anything thrown by a Firebase SDK into an [AppException].
AppException mapFirebaseException(Object error, StackTrace stackTrace) {
  if (error is AppException) {
    return error;
  }

  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        const PermissionDeniedException('That email or password is incorrect.'),
      'email-already-in-use' => const PermissionDeniedException(
        'That email is already registered.',
      ),
      'account-exists-with-different-credential' ||
      'credential-already-in-use' => const AccountExistsException(),
      'operation-not-allowed' ||
      'configuration-not-found' => const SignInUnavailableException(),
      'popup-closed-by-user' ||
      'cancelled-popup-request' ||
      'web-context-canceled' ||
      'user-cancelled' => const SignInCancelledException(),
      'network-request-failed' => const NetworkException(),
      'too-many-requests' => const RateLimitedException(),
      _ => UnauthenticatedException(
        error.message ?? 'Could not sign you in.',
        error,
        stackTrace,
      ),
    };
  }

  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => const UnauthenticatedException(),
      'permission-denied' => const PermissionDeniedException(),
      'not-found' => const NotFoundException(),
      'resource-exhausted' => const RateLimitedException(),
      'unavailable' => const NetworkException(
        'That service is unavailable right now.',
      ),
      _ => UnexpectedException(
        error.message ?? 'The request failed.',
        error,
        stackTrace,
      ),
    };
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => const PermissionDeniedException(),
      'not-found' || 'object-not-found' => const NotFoundException(),
      'unavailable' || 'network-request-failed' => const NetworkException(),
      'resource-exhausted' || 'quota-exceeded' => const RateLimitedException(),
      'unauthenticated' || 'unauthorized' => const UnauthenticatedException(),
      _ => UnexpectedException(
        error.message ?? 'The request failed.',
        error,
        stackTrace,
      ),
    };
  }

  return UnexpectedException('Something went wrong.', error, stackTrace);
}

/// Runs [action], translating any Firebase failure into an [AppException].
Future<T> guardFirebase<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on Object catch (error, stackTrace) {
    throw mapFirebaseException(error, stackTrace);
  }
}
