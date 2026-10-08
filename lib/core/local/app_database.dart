import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CachedDocuments extends Table {
  TextColumn get collection => text()();
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get payload => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {collection, id};
}

class PendingOperations extends Table {
  TextColumn get id => text()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  TextColumn get body => text().nullable()();
  TextColumn get idempotencyKey => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedDocuments, PendingOperations])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'raices'));

  @override
  int get schemaVersion => 1;

  Stream<List<CachedDocument>> watchCollection(
    String collection, {
    String? parentId,
  }) {
    final query = select(cachedDocuments)
      ..where((row) => row.collection.equals(collection));
    if (parentId != null) {
      query.where((row) => row.parentId.equals(parentId));
    }
    query.orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch();
  }

  Future<CachedDocument?> readDocument(String collection, String id) {
    return (select(cachedDocuments)..where(
          (row) => row.collection.equals(collection) & row.id.equals(id),
        ))
        .getSingleOrNull();
  }

  Future<void> saveDocument({
    required String collection,
    required String id,
    required String payload,
    String? parentId,
    int? updatedAt,
  }) {
    return into(cachedDocuments).insertOnConflictUpdate(
      CachedDocumentsCompanion.insert(
        collection: collection,
        id: id,
        parentId: Value(parentId),
        payload: payload,
        updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Drops this device's copy of the signed-in garden. Shared species stay.
  Future<void> clearPersonalData() {
    return transaction(() async {
      await (delete(cachedDocuments)..where(
            (row) => row.collection.isIn(const [
              'plants',
              'care_events',
              'reminders',
              'photos',
              'tokens',
              'gardens',
            ]),
          ))
          .go();
      await delete(pendingOperations).go();
    });
  }

  Future<void> removeDocument(String collection, String id) {
    return (delete(cachedDocuments)..where(
          (row) => row.collection.equals(collection) & row.id.equals(id),
        ))
        .go();
  }

  Future<void> enqueue({
    required String id,
    required String method,
    required String path,
    String? body,
    String? idempotencyKey,
  }) {
    return into(pendingOperations).insertOnConflictUpdate(
      PendingOperationsCompanion.insert(
        id: id,
        method: method,
        path: path,
        body: Value(body),
        idempotencyKey: Value(idempotencyKey),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<PendingOperation>> pending() {
    return (select(pendingOperations)..orderBy([
          (row) => OrderingTerm.asc(row.createdAt),
        ]))
        .get();
  }

  Future<void> dropPending(String id) {
    return (delete(pendingOperations)..where((row) => row.id.equals(id))).go();
  }

  Future<void> notePendingFailure(String id, String message) async {
    final row = await (select(pendingOperations)
          ..where((row) => row.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (update(pendingOperations)..where((row) => row.id.equals(id))).write(
      PendingOperationsCompanion(
        attempts: Value(row.attempts + 1),
        lastError: Value(message),
      ),
    );
  }
}
