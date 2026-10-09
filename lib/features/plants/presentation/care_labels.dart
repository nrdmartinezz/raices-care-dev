/// Wording for the dates and catalog readings the plant screens show.
///
/// "Now" is always passed in rather than read from the clock, so a screen can
/// be pinned to a fixed time in a test.
library;

/// "Due today", "Tomorrow", "In 4 days", "2 days late".
String dueLabel(DateTime dueAt, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
  final days = due.difference(today).inDays;
  return switch (days) {
    0 => 'Due today',
    1 => 'Tomorrow',
    < 0 => '${-days} ${days == -1 ? 'day' : 'days'} late',
    _ => 'In $days days',
  };
}

/// True when [lastWateredAt] falls on the same local calendar day as [now].
bool wateredToday(DateTime? lastWateredAt, DateTime now) {
  if (lastWateredAt == null) return false;
  return _sameDay(lastWateredAt, now);
}

/// "2 yrs 4 mos", "3 mos", or "12 days" from [from] until [now].
String estimatedAgeLabel(DateTime from, DateTime now) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(now.year, now.month, now.day);
  if (end.isBefore(start)) return 'Not set';

  var years = end.year - start.year;
  var months = end.month - start.month;
  if (end.day < start.day) months -= 1;
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years <= 0 && months <= 0) {
    final days = end.difference(start).inDays;
    if (days <= 0) return 'Today';
    return days == 1 ? '1 day' : '$days days';
  }
  if (years <= 0) return months == 1 ? '1 mo' : '$months mos';
  final yearLabel = years == 1 ? '1 yr' : '$years yrs';
  if (months <= 0) return yearLabel;
  final monthLabel = months == 1 ? '1 mo' : '$months mos';
  return '$yearLabel $monthLabel';
}

/// "Last watered today" or "Last watered Oct 21".
String lastWateredCaption(DateTime? lastWateredAt, DateTime now) {
  if (lastWateredAt == null) return 'Not watered yet';
  if (_sameDay(lastWateredAt, now)) return 'Last watered today';
  return 'Last watered ${_monthDay(lastWateredAt)}';
}

/// "Next check Oct 28".
String nextCheckLabel(DateTime at) => 'Next check ${_monthDay(at)}';

bool _sameDay(DateTime a, DateTime b) {
  final left = a.toLocal();
  final right = b.toLocal();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _monthDay(DateTime at) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = at.toLocal();
  return '${months[local.month - 1]} ${local.day}';
}

/// "TODAY", "YESTERDAY", "4 DAYS AGO", then a plain date.
String writtenLabel(DateTime at, {required DateTime now}) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  return switch (days) {
    <= 0 => 'TODAY',
    1 => 'YESTERDAY',
    < 7 => '$days DAYS AGO',
    _ => '${at.day}/${at.month}/${at.year}',
  };
}

/// Trefle grades light 0–10, where 10 is full sun.
String lightLabel(int? light) => switch (light) {
  null => 'Not known',
  >= 9 => 'Full sun',
  >= 7 => 'Plenty of direct sun',
  >= 5 => 'Bright, indirect light',
  >= 3 => 'Partial shade',
  _ => 'Low light',
};
