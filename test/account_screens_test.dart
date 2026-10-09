import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';
import 'package:raices/features/auth/data/auth_repository.dart';
import 'package:raices/features/auth/domain/app_user.dart';
import 'package:raices/features/home/data/home_providers.dart';
import 'package:raices/features/plants/data/plant_repository.dart';
import 'package:raices/features/profile/data/account_gateway.dart';
import 'package:raices/features/weather/data/weather_providers.dart';
import 'package:raices/features/weather/domain/garden_weather.dart';

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _FakeAccountGateway implements AccountGateway {
  int signOuts = 0;
  int passwordUpdates = 0;
  int accountDeletions = 0;

  @override
  bool get canChangePassword => true;

  @override
  String? get externalProviderLabel => null;

  @override
  Future<void> requestEmailUpdate(String email, {String? currentPassword}) {
    return Future.value();
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordUpdates++;
  }

  @override
  Future<void> updatePhone(AppUser user, String phone) {
    return Future.value();
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }

  @override
  Future<void> deleteAccount({String? currentPassword}) async {
    accountDeletions++;
  }
}

Widget _app(_FakeAccountGateway gateway) => ProviderScope(
  overrides: [
    authStatusProvider.overrideWithValue(AuthStatus.signedIn),
    nowProvider.overrideWithValue(DateTime(2026, 10, 3, 9)),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        AppUser(
          id: 'gardener',
          displayName: 'Martín',
          onboardingCompletedAt: DateTime.utc(2026, 1, 1),
        ),
      ),
    ),
    accountGatewayProvider.overrideWithValue(gateway),
    activePlantsProvider.overrideWith((ref) => Stream.value(const [])),
    todaysRemindersProvider.overrideWith((ref) => Stream.value(const [])),
    gardenWeatherProvider.overrideWith(
      (ref) => Future.value(
        const GardenWeather(
          temperatureCelsius: 22.2,
          sky: 'Sunny',
          place: 'Austin, TX',
          humidityPercent: 48,
        ),
      ),
    ),
  ],
  child: const RaicesApp(),
);

Future<void> _openProfile(WidgetTester tester) async {
  await tester.pumpWidget(_app(_FakeAccountGateway()));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.bySemanticsLabel('Profile'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profile shows the account and opens settings', (tester) async {
    _usePhoneSurface(tester);
    await _openProfile(tester);

    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Martín'), findsWidgets);
    expect(find.text('Not added yet'), findsNWidgets(2));
    expect(find.text('YOUR RAÍCES ACCOUNT'), findsOneWidget);

    await tester.tap(find.text('Account settings'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR ACCOUNT'), findsOneWidget);
    expect(find.text('No email added yet'), findsOneWidget);
    expect(find.text('No phone added yet'), findsOneWidget);
    expect(find.text('Danger zone'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('profile opens support with bug reports and Patreon', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    await _openProfile(tester);

    expect(
      find.text('Report a bug or support the app on Patreon'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Opens a separate support screen with bug reporting and Patreon '
        'support options.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Support'));
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR ACCOUNT'), findsOneWidget);
    expect(find.text('Support'), findsWidgets);
    expect(
      find.text(
        'A little help goes a long way. Let’s keep Raíces growing together.',
      ),
      findsOneWidget,
    );
    expect(find.text('Report a bug'), findsNWidgets(2));
    expect(find.text('Support on Patreon'), findsNWidgets(2));
    expect(find.text('Thank you for helping Raíces grow.'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a mismatched password is rejected and sign out is called', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    final gateway = _FakeAccountGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account settings'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter current password'),
      'current-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter new password'),
      'new-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Re-enter new password'),
      'different-password',
    );
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(find.text('Those passwords do not match.'), findsOneWidget);
    expect(gateway.passwordUpdates, 0);

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(gateway.signOuts, 0);

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Sign out')),
    );
    await tester.pump();

    expect(gateway.signOuts, 1);
  });

  testWidgets('delete account waits for confirmation', (tester) async {
    _usePhoneSurface(tester);
    final gateway = _FakeAccountGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account settings'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(gateway.accountDeletions, 0);

    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Delete account'),
      ),
    );
    await tester.pump();

    expect(gateway.accountDeletions, 1);
  });
}
