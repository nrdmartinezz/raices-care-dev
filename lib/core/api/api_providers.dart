import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../local/app_database.dart';
import '../sync/sync_engine.dart';
import 'api_client.dart';
import 'worker_backend.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(auth: ref.watch(firebaseAuthProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    database: ref.watch(appDatabaseProvider),
    client: ref.watch(apiClientProvider),
  );
  engine.listen();
  ref.onDispose(engine.dispose);
  return engine;
});

final workerBackendProvider = Provider<WorkerBackend>(
  (ref) => WorkerBackend(
    client: ref.watch(apiClientProvider),
    database: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);
