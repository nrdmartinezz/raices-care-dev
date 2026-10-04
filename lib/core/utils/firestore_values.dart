import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/app_exception.dart';

/// Schema version stamped onto long-lived documents. Matches SCHEMA_VERSION in
/// functions/src/schema.ts.
const int kSchemaVersion = 1;

/// Lenient readers for Firestore values.
///
/// Documents written by older app versions, or by the catalog importer against
/// a sparse upstream record, routinely omit fields. These return null or an
/// empty collection rather than throwing, so one missing field cannot break a
/// whole list.
abstract final class FirestoreValue {
  static DateTime? dateTime(Object? value) => switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    _ => null,
  };

  static DateTime requireDateTime(Object? value, String field) {
    final parsed = dateTime(value);
    if (parsed == null) {
      throw MalformedDataException('Expected a timestamp at "$field".');
    }
    return parsed;
  }

  static String requireText(Object? value, String field) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw MalformedDataException('Expected a non-empty string at "$field".');
  }

  static String? text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static List<String> strings(Object? value) => value is Iterable
      ? value.whereType<String>().toList(growable: false)
      : const <String>[];

  static Map<String, dynamic> map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};

  static double? decimal(Object? value) => (value as num?)?.toDouble();

  static int? integer(Object? value) => (value as num?)?.toInt();

  static bool boolean(Object? value, {bool fallback = false}) =>
      value is bool ? value : fallback;
}

/// Reads a document that must exist, for models whose required fields cannot
/// be defaulted.
extension DocumentSnapshotX on DocumentSnapshot<Map<String, dynamic>> {
  Map<String, dynamic> requireData() {
    final value = data();
    if (value == null) {
      throw NotFoundException('Document ${reference.path} has no data.');
    }
    return value;
  }
}

/// Drops null entries so a partial update never blanks a stored field.
Map<String, Object?> withoutNulls(Map<String, Object?> source) {
  return {
    for (final entry in source.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
