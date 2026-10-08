import 'package:flutter_test/flutter_test.dart';
import 'package:raices/features/planting/domain/harvest_countdown.dart';

void main() {
  final created = DateTime(2026, 3, 1);

  test('counts down from the day the plant was added', () {
    expect(
      HarvestCountdown.remainingDays(
        daysToHarvest: 75,
        createdAt: created,
        now: DateTime(2026, 3, 11),
      ),
      65,
    );
  });

  test('reads ready once the count reaches zero', () {
    expect(
      HarvestCountdown.remainingDays(
        daysToHarvest: 10,
        createdAt: created,
        now: DateTime(2026, 3, 20),
      ),
      0,
    );
    expect(HarvestCountdown.label(0), 'Ready to harvest');
  });

  test('hides the count without a created date or a day total', () {
    expect(
      HarvestCountdown.remainingDays(
        daysToHarvest: 40,
        createdAt: null,
        now: created,
      ),
      isNull,
    );
    expect(
      HarvestCountdown.remainingDays(
        daysToHarvest: null,
        createdAt: created,
        now: created,
      ),
      isNull,
    );
  });
}
