import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';
import 'package:raices/app/router.dart';
import 'package:raices/features/auth/data/auth_repository.dart';
import 'package:raices/features/auth/domain/app_user.dart';
import 'package:raices/features/care/data/reminder_repository.dart';
import 'package:raices/features/care/domain/care_task_type.dart';
import 'package:raices/features/care/domain/reminder.dart';
import 'package:raices/features/home/data/home_providers.dart';
import 'package:raices/features/plants/data/observation_repository.dart';
import 'package:raices/features/plants/data/plant_repository.dart';
import 'package:raices/features/plants/data/species_repository.dart';
import 'package:raices/features/plants/domain/care_profile.dart';
import 'package:raices/features/plants/domain/garden_spot.dart';
import 'package:raices/features/plants/domain/plant.dart';
import 'package:raices/features/plants/domain/species.dart';
import 'package:raices/features/weather/data/weather_providers.dart';
import 'package:raices/features/weather/domain/garden_weather.dart';

final _now = DateTime(2026, 10, 3, 9);

final _plant = Plant(
  id: 'p1',
  speciesId: 'sp1',
  displayName: 'Tomato',
  gardenId: GardenSpot.backyard.wire,
  locationType: LocationType.outdoor,
  growingMethod: GrowingMethod.inGround,
  plantAgeStage: PlantAgeStage.seedling,
  status: const PlantStatus(health: PlantHealth.healthy),
);

const _species = Species(
  id: 'sp1',
  scientificName: 'Solanum lycopersicum',
  commonName: 'Tomato',
  growth: SpeciesGrowth(light: 8),
  attribution: SpeciesAttribution(text: 'Catalog data from Trefle'),
);

const _profile = CareProfile(
  id: 'derived',
  label: 'Derived care',
  isDerived: true,
  tasks: [
    CareProfileTask(
      taskType: ReminderTaskType.waterCheck,
      title: 'Check soil moisture',
      intervalDays: 5,
      basis: ['growth.soilMoisture'],
    ),
  ],
);

const _careSchedule = ReminderSchedule(
  mode: ScheduleMode.interval,
  source: ScheduleSource.careProfile,
  careProfileId: 'derived',
  intervalDays: 5,
);

final _reminders = [
  Reminder(
    id: 'r1',
    plantId: 'p1',
    taskType: ReminderTaskType.waterCheck,
    title: 'Check soil moisture',
    dueAt: _now,
    schedule: _careSchedule,
  ),
  Reminder(
    id: 'r2',
    plantId: 'p1',
    taskType: ReminderTaskType.fertilize,
    title: 'Feed the soil',
    dueAt: _now.add(const Duration(days: 10)),
    schedule: _careSchedule,
  ),
];

/// The app with every Firebase-backed provider the plant screens read stubbed
/// out, so routing and layout can be pumped without an initialized Firebase
/// app.
ProviderContainer _container({List<Reminder>? reminders}) => ProviderContainer(
  overrides: [
    authStatusProvider.overrideWithValue(AuthStatus.signedIn),
    nowProvider.overrideWithValue(_now),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        AppUser(
          id: 'gardener',
          onboardingCompletedAt: DateTime.utc(2026, 1, 1),
        ),
      ),
    ),
    activePlantsProvider.overrideWith((ref) => Stream.value([_plant])),
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
    plantProvider('p1').overrideWith((ref) => Stream.value(_plant)),
    speciesProvider('sp1').overrideWith((ref) => Stream.value(_species)),
    careProfilesProvider('sp1').overrideWith((ref) => Future.value([_profile])),
    plantRemindersProvider('p1')
        .overrideWith((ref) => Stream.value(reminders ?? _reminders)),
    plantObservationsProvider('p1')
        .overrideWith((ref) => Stream.value(const [])),
  ],
);

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  List<Reminder>? reminders,
}) async {
  final container = _container(reminders: reminders);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const RaicesApp()),
  );
  await tester.pump(); // profile resolves; the router leaves the splash
  await tester.pump(); // section streams deliver their first value
  return container;
}

void main() {
  testWidgets('the add-plant flow opens on step one', (tester) async {
    final container = await _pumpApp(tester);

    container.read(routerProvider).goNamed(AddPlantRoute.name);
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('Choose a plant'), findsOneWidget);
    expect(find.text('Find your next green companion'), findsOneWidget);
    expect(find.text('Recent & suggested'), findsOneWidget);
    expect(find.text('Monstera'), findsOneWidget);
  });

  testWidgets('the plant profile replaces the shell header and keeps the nav', (
    tester,
  ) async {
    final container = await _pumpApp(tester);

    container
        .read(routerProvider)
        .goNamed(PlantDetailRoute.name, pathParameters: {'plantId': 'p1'});
    await tester.pumpAndSettle();

    // The logo bar gives way to the back-and-title header, but the tabs stay.
    expect(find.text('MY PLANTS'), findsOneWidget);
    expect(find.text('Plant profile'), findsOneWidget);
    expect(find.text('Chores'), findsOneWidget);
  });

  testWidgets('the plant profile shows the plant, its spot and its care', (
    tester,
  ) async {
    final container = await _pumpApp(tester);

    container
        .read(routerProvider)
        .goNamed(PlantDetailRoute.name, pathParameters: {'plantId': 'p1'});
    await tester.pumpAndSettle();

    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Solanum lycopersicum'), findsOneWidget);

    // Garden, stage and condition, each from the plant document.
    expect(find.text('Backyard'), findsOneWidget);
    expect(find.text('Seedling'), findsOneWidget);
    expect(find.text('Thriving'), findsOneWidget);

    // The soonest reminder leads; the rest fall under upcoming care.
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Feed the soil', skipOffstage: false), findsOneWidget);
    expect(find.text('In 10 days', skipOffstage: false), findsOneWidget);

    // Watering comes from the care profile, light from the catalog record.
    expect(find.text('Every 5 days', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Plenty of direct sun', skipOffstage: false),
      findsOneWidget,
    );

    // Care-profile reminders mean the plant is already on the schedule.
    expect(find.text('On the schedule', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Remove from chores', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Add to chores', skipOffstage: false), findsNothing);
  });

  testWidgets('a plant with no chores offers to add it', (tester) async {
    final container = await _pumpApp(tester, reminders: const []);

    container
        .read(routerProvider)
        .goNamed(PlantDetailRoute.name, pathParameters: {'plantId': 'p1'});
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This plant is not on the chores list yet.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('Add to chores', skipOffstage: false), findsOneWidget);
    expect(find.text('Remove from chores', skipOffstage: false), findsNothing);
    expect(find.text('On the schedule', skipOffstage: false), findsNothing);
  });
}
