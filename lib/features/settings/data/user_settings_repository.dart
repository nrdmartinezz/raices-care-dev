import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/firestore_values.dart';
import '../../auth/domain/app_user.dart';

/// Private per-user settings at /users/{uid}/settings/private.
///
/// Push tokens live here rather than on the profile document so they are never
/// readable alongside anything that might later become public.
class UserSettingsRepository {
  UserSettingsRepository({
    required this._firestore,
    required this._messaging,
    required this._userId,
  });

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final String? _userId;

  Stream<List<String>> watchDeviceTokens() {
    return _settingsRef.snapshots().map(
      (snapshot) =>
          FirestoreValue.strings((snapshot.data() ?? const {})['fcmTokens']),
    );
  }

  /// Asks for notification permission and registers this device.
  ///
  /// Call after sign-in. `generateDueReminderNotifications` reads these tokens,
  /// and skips a user entirely when the list is empty.
  Future<bool> enablePushNotifications() {
    return guardFirebase(() async {
      final settings = await _messaging.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!granted) {
        return false;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await registerDeviceToken(token);
      }
      return true;
    });
  }

  Future<void> registerDeviceToken(String token) {
    return guardFirebase(
      () => _settingsRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': kSchemaVersion,
      }, SetOptions(merge: true)),
    );
  }

  /// Drops this device's token, for sign-out.
  Future<void> removeCurrentDeviceToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await removeDeviceToken(token);
    }
  }

  /// Drops a token. Do this on sign-out, or the next person to use the device
  /// receives the previous user's reminders.
  Future<void> removeDeviceToken(String token) {
    return guardFirebase(
      () => _settingsRef.set({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  /// Keeps the stored token current when FCM rotates it.
  Stream<String> onTokenRefresh() => _messaging.onTokenRefresh;

  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    final uid = _requireUserId();
    return guardFirebase(
      () => _firestore.collection('users').doc(uid).set({
        'notificationPreferences': preferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': kSchemaVersion,
      }, SetOptions(merge: true)),
    );
  }

  String _requireUserId() {
    final uid = _userId;
    if (uid == null) {
      throw const UnauthenticatedException();
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _settingsRef => _firestore
      .collection('users')
      .doc(_requireUserId())
      .collection('settings')
      .doc('private');
}

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>(
  (ref) => UserSettingsRepository(
    firestore: ref.watch(firestoreProvider),
    messaging: ref.watch(firebaseMessagingProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);
