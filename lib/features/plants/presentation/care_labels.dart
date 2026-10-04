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
