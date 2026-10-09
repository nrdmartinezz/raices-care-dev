import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/core/local/app_database.dart';
import 'package:raices/features/planting/data/planting_repository.dart';

void main() {
  const saved = GardenFrostReady(
    zone: '9b',
    frost: FrostDates(
      lastSpringFrost: '2026-02-15',
      firstFallFrost: '2026-12-01',
      label: '30-year averages',
    ),
    latitude: 34.05,
    longitude: -118.24,
  );

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('a 404 uses the saved dates for this ZIP', () async {
    await saveRememberedFrost(database: database, zip: '90210', frost: saved);

    final frost = await readRememberedFrost(
      database: database,
      zip: '90210',
      zone: '9b',
    );

    expect(frost?.remembered, isTrue);
    expect(frost?.zone, '9b');
    expect(frost?.frost.lastSpringFrost, '2026-02-15');
    expect(frost?.frost.firstFallFrost, '2026-12-01');
    expect(frost?.frost.label, '30-year averages');
    expect(frost?.latitude, 34.05);
    expect(frost?.longitude, -118.24);
  });

  test('a 404 with no saved row stays unavailable', () async {
    final remembered = await readRememberedFrost(
      database: database,
      zip: '90210',
      zone: '9b',
    );
    final frost = remembered ?? const GardenFrostUnavailable(zone: '9b');

    expect(frost, isA<GardenFrostUnavailable>());
  });

  test('a saved row for another ZIP is not used', () async {
    await saveRememberedFrost(database: database, zip: '10001', frost: saved);

    final remembered = await readRememberedFrost(
      database: database,
      zip: '90210',
      zone: '9b',
    );
    final frost = remembered ?? const GardenFrostUnavailable(zone: '9b');

    expect(frost, isA<GardenFrostUnavailable>());
    expect(
      await database.readDocument(frostCacheCollection, '10001'),
      isNotNull,
    );
  });

  test('signing out drops the saved frost dates', () async {
    await saveRememberedFrost(database: database, zip: '90210', frost: saved);

    await database.clearPersonalData();

    expect(await database.readDocument(frostCacheCollection, '90210'), isNull);
  });
}
