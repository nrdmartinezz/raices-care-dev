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

  bool _isPlantPatch(PendingOperation operation) {
    if (operation.method != 'PATCH') return false;
    final parts = [
      for (final part in operation.path.split('/'))
        if (part.isNotEmpty) part,
    ];
    return parts.length == 3 && parts[0] == 'v1' && parts[1] == 'plants';
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
      Object? body;
      String? ifMatch;
      try {
        final decoded = operation.body == null
            ? null
            : jsonDecode(operation.body!);
        body = decoded;
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
        if (_isPlantPatch(operation) && isConflict(error)) {
          try {
            final latest = await _client.getJson(operation.path);
            final revision = latest['revision'];
            await _client.sendJson(
              operation.method,
              operation.path,
              body: body,
              idempotencyKey: operation.idempotencyKey,
              ifMatch: revision?.toString(),
            );
            await _database.dropPending(operation.id);
            continue;
          } on NetworkException catch (retry) {
            await _database.notePendingFailure(operation.id, retry.message);
            return;
          } catch (retry) {
            await _database.notePendingFailure(operation.id, retry.toString());
            continue;
          }
        }
        await _database.notePendingFailure(operation.id, error.toString());
      }
    }
  }
}
