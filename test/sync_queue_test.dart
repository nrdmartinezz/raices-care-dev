import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/core/local/app_database.dart';

void main() {
  test('a failed write stays queued', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.enqueue(
      id: 'plant-1',
      method: 'POST',
      path: '/v1/plants',
      body: '{"body":{"id":"plant-1"}}',
      idempotencyKey: 'plant-1',
    );
    await database.saveDocument(
      collection: 'plants',
      id: 'plant-1',
      payload: '{"id":"plant-1","nickname":"Fern"}',
    );

    final queued = await database.pending();
    expect(queued.single.path, '/v1/plants');
    expect(queued.single.idempotencyKey, 'plant-1');

    await database.notePendingFailure('plant-1', 'offline');
    expect((await database.pending()).single.attempts, 1);

    final cached = await database.readDocument('plants', 'plant-1');
    expect(cached?.payload, contains('Fern'));

    await database.dropPending('plant-1');
    expect(await database.pending(), isEmpty);
  });
}
