import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';
import 'package:raices/features/auth/data/auth_repository.dart';
import 'package:raices/features/home/data/home_providers.dart';
import 'package:raices/features/plants/data/plant_repository.dart';

/// The app with every Firebase-backed provider stubbed out, so the shell can
/// be pumped without an initialized Firebase app.
Widget _appWithEmptyGarden() => ProviderScope(
  overrides: [
    nowProvider.overrideWithValue(DateTime(2026, 10, 3, 9)),
    userProfileProvider.overrideWith((ref) => Stream.value(null)),
    activePlantsProvider.overrideWith((ref) => Stream.value(const [])),
    todaysRemindersProvider.overrideWith((ref) => Stream.value(const [])),
  ],
  child: const RaicesApp(),
);

void main() {
  testWidgets('home shows empty states for a garden with no plants', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithEmptyGarden());
    await tester.pump();

    expect(find.text("Today's Ritual"), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsOneWidget);
    expect(find.text('Growing Now'), findsOneWidget);
    expect(find.text('No plants yet'), findsOneWidget);
  });

  testWidgets('greeting reads from the clock and the profile', (tester) async {
    await tester.pumpWidget(_appWithEmptyGarden());
    await tester.pump();

    expect(find.text('SATURDAY, OCTOBER 3'), findsOneWidget);
    expect(find.text('Good morning,\ngardener'), findsOneWidget);
  });

  testWidgets('bottom nav switches between tabs', (tester) async {
    await tester.pumpWidget(_appWithEmptyGarden());
    await tester.pump();

    await tester.tap(find.text('Chores'));
    await tester.pumpAndSettle();
    expect(find.text('THE SCHEDULE'), findsOneWidget);

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
