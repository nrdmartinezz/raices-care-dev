/// Days left until harvest, counted from the day the plant was added.
class HarvestCountdown {
  const HarvestCountdown._();

  static int? remainingDays({
    required int? daysToHarvest,
    required DateTime? createdAt,
    required DateTime now,
  }) {
    if (daysToHarvest == null || daysToHarvest < 0 || createdAt == null) {
      return null;
    }
    final start = DateTime.utc(createdAt.year, createdAt.month, createdAt.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    final elapsed = today.difference(start).inDays;
    final spent = elapsed < 0 ? 0 : elapsed;
    final remaining = daysToHarvest - spent;
    return remaining < 0 ? 0 : remaining;
  }

  static String label(int days) {
    if (days == 0) return 'Ready to harvest';
    if (days == 1) return '1 day until harvest';
    return '$days days until harvest';
  }
}
