import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_client.dart';
import '../errors/app_exception.dart';
import '../local/app_database.dart';

/// Pushes queued writes when the device is online.
///
/// A failed attempt stays in the queue. The same idempotency key is sent again
/// so a retry cannot create a second plant or care event.
class SyncEngine {
  SyncEngine({
    required this._database,
    required this._client,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  final AppDatabase _database;
  final ApiClient _client;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void listen() {
    _subscription ??= _connectivity.onConnectivityChanged.listen((_) {
      unawaited(flush());
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> flush() async {
    final results = await _connectivity.checkConnectivity();
    if (results.every((result) => result == ConnectivityResult.none)) {
      return;
    }
    final queued = await _database.pending();
    for (final operation in queued) {
      try {
        final decoded = operation.body == null ? null : jsonDecode(operation.body!);
        Object? body = decoded;
        String? ifMatch;
        if (decoded is Map<String, dynamic> && decoded.containsKey('body')) {
          body = decoded['body'];
          final match = decoded['ifMatch'];
          if (match is String) ifMatch = match;
        }
        await _client.sendJson(
          operation.method,
          operation.path,
          body: body,
          idempotencyKey: operation.idempotencyKey,
          ifMatch: ifMatch,
        );
        await _database.dropPending(operation.id);
      } on NetworkException catch (error) {
        await _database.notePendingFailure(operation.id, error.message);
        return;
      } catch (error) {
        await _database.notePendingFailure(operation.id, error.toString());
      }
    }
  }
}
