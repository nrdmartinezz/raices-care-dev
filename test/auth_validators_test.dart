import 'package:flutter_test/flutter_test.dart';
import 'package:raices/features/auth/domain/auth_validators.dart';

void main() {
  group('validatePassword', () {
    test('sign-in accepts any non-empty password', () {
      expect(validatePassword('short', isNewAccount: false), isNull);
    });

    test('a new password must be at least 8 characters', () {
      expect(
        validatePassword('Ab1!', isNewAccount: true),
        'Use at least 8 characters.',
      );
    });

    test('a new password needs a lowercase letter', () {
      expect(
        validatePassword('PASSWORD1!', isNewAccount: true),
        'Include a lowercase letter.',
      );
    });

    test('a new password needs an uppercase letter', () {
      expect(
        validatePassword('password1!', isNewAccount: true),
        'Include an uppercase letter.',
      );
    });

    test('a new password needs a number', () {
      expect(
        validatePassword('Password!', isNewAccount: true),
        'Include a number.',
      );
    });

    test('a new password needs a special character', () {
      expect(
        validatePassword('Password1', isNewAccount: true),
        'Include a special character.',
      );
    });

    test('accented letters count toward case', () {
      expect(validatePassword('Ñoño123!', isNewAccount: true), isNull);
    });

    test('a password that meets every rule is accepted', () {
      expect(validatePassword('Garden1!', isNewAccount: true), isNull);
    });
  });
}
