/// Field rules for the auth form.
///
/// Kept out of the widget so they can be tested directly, and so the same
/// rule is not written twice once there is a second place to change a
/// password.
library;

/// Deliberately loose. Anything stricter rejects addresses that are legal and
/// in use; the real check is whether the verification email arrives.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Firebase enforces six. The stricter rule applies only when a password is
/// being chosen, so an existing shorter password still opens sign-in.
const minNewPasswordLength = 8;

/// Shown beside a new-password field so the rule is visible before submit.
const newPasswordHint =
    'At least 8 characters, with upper and lower case, a number, and a special character.';

final _lowercaseLetter = RegExp(r'\p{Ll}', unicode: true);
final _uppercaseLetter = RegExp(r'\p{Lu}', unicode: true);
final _digit = RegExp(r'\p{Nd}', unicode: true);
final _specialCharacter = RegExp(r'[^\p{L}\p{N}]', unicode: true);

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
  if (!isNewAccount) {
    return null;
  }
  if (password.length < minNewPasswordLength) {
    return 'Use at least $minNewPasswordLength characters.';
  }
  if (!_lowercaseLetter.hasMatch(password)) {
    return 'Include a lowercase letter.';
  }
  if (!_uppercaseLetter.hasMatch(password)) {
    return 'Include an uppercase letter.';
  }
  if (!_digit.hasMatch(password)) {
    return 'Include a number.';
  }
  if (!_specialCharacter.hasMatch(password)) {
    return 'Include a special character.';
  }
  return null;
}

String? validatePhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return 'Enter your phone number.';
  }
  if (phone.length > 32) {
    return 'That does not look like a phone number.';
  }
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) {
    return 'That does not look like a phone number.';
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
