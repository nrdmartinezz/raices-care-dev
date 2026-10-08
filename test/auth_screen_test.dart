import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';
import 'package:raices/app/theme.dart';
import 'package:raices/features/auth/data/auth_repository.dart';
import 'package:raices/features/auth/domain/auth_mode.dart';
import 'package:raices/features/auth/domain/auth_validators.dart';
import 'package:raices/features/auth/presentation/auth_screen.dart';

/// A phone-tall surface. The default 800x600 is shorter than the auth screen,
/// which leaves the submit button and the mode toggle below the fold where
/// `tap` cannot reach them.
void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The auth screen on its own, with no router or Firebase behind it.
Widget _authScreen({AuthMode mode = AuthMode.signIn}) => ProviderScope(
  child: MaterialApp(
    theme: buildRaicesTheme(),
    home: AuthScreen(initialMode: mode),
  ),
);

/// The whole app, with the session stated rather than resolved.
Widget _appSignedOut() => ProviderScope(
  overrides: [authStatusProvider.overrideWithValue(AuthStatus.signedOut)],
  child: const RaicesApp(),
);

Widget _appResolvingSession() => ProviderScope(
  overrides: [authStatusProvider.overrideWithValue(AuthStatus.unknown)],
  child: const RaicesApp(),
);

void main() {
  group('mode toggle', () {
    testWidgets('opens on sign-in', (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen());
      await tester.pump();

      expect(find.text('ACCOUNT LOGIN'), findsOneWidget);
      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
    });

    testWidgets('swaps every piece of copy when toggled', (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen());
      await tester.pump();

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('Start your garden'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.text('ACCOUNT LOGIN'), findsNothing);
    });

    testWidgets('toggles back again', (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen(mode: AuthMode.signUp));
      await tester.pump();

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT LOGIN'), findsOneWidget);
    });
  });

  group('fields per mode', () {
    testWidgets('sign-in has no name field, and does have Forgot', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen());
      await tester.pump();

      expect(find.text('Your name'), findsNothing);
      expect(find.text('Forgot?'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
    });

    testWidgets('sign-up adds the name field and drops Forgot', (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen(mode: AuthMode.signUp));
      await tester.pump();

      expect(find.text('Your name'), findsOneWidget);
      expect(find.text('Forgot?'), findsNothing);
      // Remember me belongs to a returning session, not a new one.
      expect(find.text('Remember me'), findsNothing);
    });

    testWidgets('both modes offer Google and not Apple', (tester) async {
      _usePhoneSurface(tester);
      for (final mode in AuthMode.values) {
        await tester.pumpWidget(_authScreen(mode: mode));
        await tester.pump();

        expect(find.text('OR CONTINUE WITH'), findsOneWidget);
        expect(find.bySemanticsLabel('Continue with Apple'), findsNothing);
        expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);
      }
    });
  });

  group('validation', () {
    testWidgets('empty fields block submission', (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen());
      await tester.pump();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('a malformed email is rejected', (tester) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('That does not look like an email address.'),
        findsOneWidget,
      );
    });

    testWidgets('sign-up requires a longer password than sign-in', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen(mode: AuthMode.signUp));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Mateo');
      await tester.enterText(fields.at(1), 'mateo@tierranueva.com');
      await tester.enterText(fields.at(2), 'short');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text(newPasswordHint), findsOneWidget);
    });

    testWidgets('sign-up rejects a password missing a special character', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen(mode: AuthMode.signUp));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Mateo');
      await tester.enterText(fields.at(1), 'mateo@tierranueva.com');
      await tester.enterText(fields.at(2), 'Password1');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Include a special character.'), findsOneWidget);
    });

    testWidgets('toggling clears the errors from the other form', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_authScreen());
      await tester.pump();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address.'), findsOneWidget);

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address.'), findsNothing);
    });
  });

  group('router gate', () {
    testWidgets('a signed-out user lands on the auth screen', (tester) async {
      await tester.pumpWidget(_appSignedOut());
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Sign in to your account'), findsOneWidget);
    });

    testWidgets('an unresolved session waits on the splash, not sign-in', (
      tester,
    ) async {
      await tester.pumpWidget(_appResolvingSession());
      await tester.pump();

      expect(find.byType(AuthScreen), findsNothing);
      expect(find.text('Sign in to your account'), findsNothing);
    });
  });
}
