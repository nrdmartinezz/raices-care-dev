import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/care_event.dart';

/// Append-only care history for one user's plants.
///
/// Logging an event is the only way to advance a plant's `currentCare` and
/// `nextActions`: `onCareEventCreated` does that recalculation server-side, and
/// also rolls the matching reminder forward. Never write those plant fields
/// directly — the two would drift apart.
class CareEventRepository {
  CareEventRepository({required this._firestore, required this._userId});

  final FirebaseFirestore _firestore;
  final String? _userId;

  Future<void> logEvent({
    required String plantId,
    required CareEvent event,
  }) {
    return guardFirebase(
      () => _events(plantId).add(event.toCreateJson()),
    );
  }

  Stream<List<CareEvent>> watchHistory(String plantId, {int limit = 50}) {
    return _events(plantId)
        .orderBy('occurredAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CareEvent.fromFirestore).toList());
  }

  /// Filtered history. Backed by the `eventType, occurredAt` composite index.
  Stream<List<CareEvent>> watchHistoryOfType(
    String plantId,
    CareEventType eventType, {
    int limit = 50,
  }) {
    return _events(plantId)
        .where('eventType', isEqualTo: eventType.wire)
        .orderBy('occurredAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CareEvent.fromFirestore).toList());
  }

  /// Removes a mistaken entry.
  ///
  /// The rules allow deletes but not updates, so correcting an event means
  /// deleting it and logging a replacement. Note that deleting does not undo
  /// the recalculation it triggered.
  Future<void> deleteEvent({
    required String plantId,
    required String eventId,
  }) {
    return guardFirebase(() => _events(plantId).doc(eventId).delete());
  }

  CollectionReference<Map<String, dynamic>> _events(String plantId) {
    final uid = _userId;
    if (uid == null) {
      throw const UnauthenticatedException();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('plants')
        .doc(plantId)
        .collection('careEvents');
  }
}

final careEventRepositoryProvider = Provider<CareEventRepository>(
  (ref) => CareEventRepository(
    firestore: ref.watch(firestoreProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);
