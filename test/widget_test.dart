import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';
import 'package:raices/features/auth/data/auth_repository.dart';
import 'package:raices/features/auth/domain/app_user.dart';
import 'package:raices/features/home/data/home_providers.dart';
import 'package:raices/features/plants/data/plant_repository.dart';
import 'package:raices/features/weather/data/weather_providers.dart';
import 'package:raices/features/weather/domain/garden_weather.dart';

/// The app with every Firebase-backed provider stubbed out, so the shell can
/// be pumped without an initialized Firebase app.
///
/// `authStatusProvider` has to be stated too, or the router's redirect holds
/// the app on the splash screen waiting for a session that never resolves.
Widget _appWithEmptyGarden() => ProviderScope(
  overrides: [
    authStatusProvider.overrideWithValue(AuthStatus.signedIn),
    nowProvider.overrideWithValue(DateTime(2026, 10, 3, 9)),
    // A finished profile, so the onboarding gate opens the home screen.
    // The name stays empty and the greeting still says "gardener".
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        AppUser(
          id: 'gardener',
          onboardingCompletedAt: DateTime.utc(2026, 1, 1),
        ),
      ),
    ),
    activePlantsProvider.overrideWith((ref) => Stream.value(const [])),
    todaysRemindersProvider.overrideWith((ref) => Stream.value(const [])),
    // A fixed reading, so the strip never asks the device for a location.
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

void main() {
  testWidgets('home shows empty states for a garden with no plants', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithEmptyGarden());
    await tester.pump(); // profile resolves; the router leaves the splash
    await tester.pump(); // section streams deliver their first value
    await tester.pump(); // the ritual card paints once that value arrives

    expect(find.text("Today's Ritual"), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsNothing);
    expect(find.text('No plants yet', skipOffstage: false), findsNWidgets(2));
    expect(
      find.text(
        'Nothing to tend yet, because the garden is empty. '
        'Tap the add button to add your first plant.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('Growing Now', skipOffstage: false), findsOneWidget);
  });

  testWidgets('greeting reads from the clock and the profile', (tester) async {
    await tester.pumpWidget(_appWithEmptyGarden());
    await tester.pump(); // profile resolves; the router leaves the splash
    await tester.pump(); // section streams deliver their first value

    expect(find.text('SATURDAY, OCTOBER 3'), findsOneWidget);
    expect(find.text('Good morning,\ngardener'), findsOneWidget);
    expect(find.text('72°F'), findsOneWidget);
    expect(find.text('Sunny'), findsOneWidget);
    expect(find.text('Austin, TX'), findsOneWidget);
    expect(find.text('48%'), findsOneWidget);
    expect(find.text('UV 6'), findsNothing);
  });

  testWidgets('bottom nav switches between tabs', (tester) async {
    await tester.pumpWidget(_appWithEmptyGarden());
    await tester.pump(); // profile resolves; the router leaves the splash
    await tester.pump(); // section streams deliver their first value

    await tester.tap(find.text('Chores'));
    await tester.pumpAndSettle();
    expect(find.text('Garden Chores'), findsOneWidget);

    await tester.tap(find.text('Wisdom'));
    await tester.pumpAndSettle();
    expect(find.text('GROWING LORE'), findsOneWidget);

    await tester.tap(find.text('My Plants'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR GARDEN'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text("Today's Ritual"), findsOneWidget);
  });
}
