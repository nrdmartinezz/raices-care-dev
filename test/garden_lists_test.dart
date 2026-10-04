import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';
import 'package:raices/features/auth/data/auth_repository.dart';
import 'package:raices/features/auth/domain/app_user.dart';
import 'package:raices/features/care/data/reminder_repository.dart';
import 'package:raices/features/home/data/home_providers.dart';
import 'package:raices/features/plants/data/plant_repository.dart';
import 'package:raices/features/plants/domain/plant.dart';
import 'package:raices/features/weather/data/weather_providers.dart';
import 'package:raices/features/weather/domain/garden_weather.dart';

final _plant = Plant(
  id: 'p1',
  speciesId: 'sp1',
  displayName: 'Tomato',
  speciesNameSnapshot: 'Solanum lycopersicum',
  gardenId: 'back_yard',
  plantAgeStage: PlantAgeStage.seedling,
  status: const PlantStatus(health: PlantHealth.healthy),
);

List<Override> _gardenOverrides(Stream<List<Plant>> plants) => [
  authStatusProvider.overrideWithValue(AuthStatus.signedIn),
  nowProvider.overrideWithValue(DateTime(2026, 10, 3, 9)),
  userProfileProvider.overrideWith(
    (ref) => Stream.value(
      AppUser(id: 'gardener', onboardingCompletedAt: DateTime.utc(2026, 1, 1)),
    ),
  ),
  activePlantsProvider.overrideWith((ref) => plants),
  todaysRemindersProvider.overrideWith((ref) => Stream.value(const [])),
  openRemindersProvider.overrideWith((ref) => Stream.value(const [])),
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
];

/// A read that produced an empty list and then failed, the way a snapshot
/// error keeps the last value.
Stream<List<Plant>> _emptyThenFail() async* {
  yield const [];
  throw StateError('failed-precondition');
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // profile resolves; the router leaves the splash
  await tester.pump(); // section streams deliver their first value
  await tester.pump(); // a following error, or the ritual card, paints
}

void main() {
  testWidgets('a plant with nothing due shows on both gardens', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _gardenOverrides(Stream.value([_plant])),
        child: const RaicesApp(),
      ),
    );
    await _settle(tester);

    expect(find.text('All done for today'), findsOneWidget);
    expect(find.text('No plants yet', skipOffstage: false), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Tomato').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Solanum lycopersicum'), findsOneWidget);
    expect(find.text('View all 1'), findsOneWidget);

    await tester.tap(find.text('My Plants'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR GARDEN'), findsOneWidget);
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('1 plant'), findsOneWidget);
    expect(find.text('No plants yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed plant read is not shown as an empty garden', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // One failure is enough. The default retry would keep the stream
        // rebuilding for several seconds.
        retry: (_, _) => null,
        overrides: _gardenOverrides(_emptyThenFail()),
        child: const RaicesApp(),
      ),
    );
    await _settle(tester);
    await tester.pumpAndSettle();

    expect(find.text('Your plants could not load'), findsOneWidget);
    expect(find.text('No plants yet', skipOffstage: false), findsNothing);
    expect(find.text('All done for today'), findsNothing);

    await tester.tap(find.text('My Plants'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your plants could not load. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('No plants yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
