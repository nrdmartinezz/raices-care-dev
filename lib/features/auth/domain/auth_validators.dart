/// Field rules for the auth form.
///
/// Kept out of the widget so they can be tested directly, and so the same
/// rule is not written twice once there is a second place to change a
/// password.
library;

/// Deliberately loose. Anything stricter rejects addresses that are legal and
/// in use; the real check is whether the verification email arrives.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Firebase enforces six. Eight is asked of new accounts only, so existing
/// users with a shorter password are not locked out of their own sign-in.
const minNewPasswordLength = 8;

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Enter your email address.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'That does not look like an email address.';
  }
  return null;
}

String? validatePassword(String? value, {required bool isNewAccount}) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Enter your password.';
  }
  if (isNewAccount && password.length < minNewPasswordLength) {
    return 'Use at least $minNewPasswordLength characters.';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Tell us what to call you.';
  }
  return null;
}
