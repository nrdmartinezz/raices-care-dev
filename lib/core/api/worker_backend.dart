import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../features/care/domain/care_event.dart';
import '../../features/care/domain/care_task_type.dart';
import '../../features/care/domain/reminder.dart';
import '../../features/photos/domain/plant_photo.dart';
import '../../features/plants/data/species_repository.dart';
import '../../features/plants/domain/care_profile.dart';
import '../../features/plants/domain/plant.dart';
import '../../features/plants/domain/search_filters.dart';
import '../../features/plants/domain/species.dart';
import '../errors/app_exception.dart';
import '../local/app_database.dart';
import '../sync/sync_engine.dart';
import 'api_client.dart';
import 'authenticated_image.dart';

/// Local cache plus the Worker. Widgets keep using the existing repositories.
class WorkerBackend {
  WorkerBackend({
    required this._client,
    required AppDatabase database,
    required this._sync,
    required this._userId,
  }) : _database = database;

  final ApiClient _client;
  final AppDatabase _database;
  final SyncEngine _sync;
  final String? _userId;
  static const _uuid = Uuid();

  List<Plant> _activePlants(Iterable<Plant> plants) {
    final active = [
      for (final plant in plants)
        if (!plant.status.isArchived) plant,
    ];
    active.sort((a, b) => a.displayName.compareTo(b.displayName));
    return active;
  }

  String get _user {
    final userId = _userId;
    if (userId == null) throw const UnauthenticatedException();
    return userId;
  }

  Stream<List<Plant>> watchActivePlants() {
    unawaited(_pullPlants());
    return _database
        .watchCollection('plants')
        .map((rows) => _activePlants(rows.map((row) => _plant(row.payload))));
  }

  Stream<List<Plant>> watchPlantsInGarden(String gardenId) {
    return watchActivePlants().map(
      (plants) => [
        for (final plant in plants)
          if (plant.gardenId == gardenId) plant,
      ],
    );
  }

  Stream<Plant?> watchPlant(String plantId) {
    unawaited(_pullPlants());
    return _database.watchCollection('plants').map((rows) {
      for (final row in rows) {
        if (row.id == plantId) return _plant(row.payload);
      }
      return null;
    });
  }

  Future<Plant?> getPlant(String plantId) async {
    await _pullPlants();
    final row = await _database.readDocument('plants', plantId);
    return row == null ? null : _plant(row.payload);
  }

  Future<String> createPlant(Plant plant) async {
    final id = plant.id.isEmpty ? _uuid.v4() : plant.id;
    final spot = plant.gardenId ?? 'indoor';
    final gardenId = _gardenId(spot);
    final body = <String, Object?>{
      'id': id,
      'gardenId': gardenId,
      'nickname': plant.displayName,
      'locationType': plant.locationType.wire,
      'health': plant.status.health.wire,
      if (plant.speciesId.isNotEmpty) 'speciesId': plant.speciesId,
      if (plant.careProfileId != null) 'careProfileId': plant.careProfileId,
      if (plant.acquiredAt != null)
        'acquiredAt': plant.acquiredAt!.toUtc().toIso8601String(),
      if (plant.plantedAt != null)
        'plantedAt': plant.plantedAt!.toUtc().toIso8601String(),
    };
    await _queue(
      id: 'garden-$gardenId',
      method: 'POST',
      path: '/v1/gardens',
      body: {'id': gardenId, 'name': _gardenName(spot)},
      idempotencyKey: gardenId,
    );
    await _database.saveDocument(
      collection: 'plants',
      id: id,
      parentId: spot,
      payload: jsonEncode({...body, 'gardenId': spot, 'revision': 1}),
    );
    await _queue(
      id: 'plant-$id',
      method: 'POST',
      path: '/v1/plants',
      body: body,
      idempotencyKey: id,
    );
    await _flushQuietly();
    return id;
  }

  Future<void> updatePlant(Plant plant) async {
    final cached = await _database.readDocument('plants', plant.id);
    final revision = cached == null ? null : _json(cached.payload)['revision'];
    final body = <String, Object?>{
      'nickname': plant.displayName,
      'locationType': plant.locationType.wire,
      'health': plant.status.health.wire,
      if (plant.gardenId != null) 'gardenId': _gardenId(plant.gardenId!),
    };
    await _queue(
      id: 'plant-update-${plant.id}',
      method: 'PATCH',
      path: '/v1/plants/${plant.id}',
      body: body,
      ifMatch: revision?.toString(),
    );
    await _flushQuietly();
  }

  Future<void> archivePlant(String plantId) async {
    final cached = await _database.readDocument('plants', plantId);
    final revision = cached == null ? null : _json(cached.payload)['revision'];
    await _queue(
      id: 'plant-archive-$plantId',
      method: 'PATCH',
      path: '/v1/plants/$plantId',
      body: {'archivedAt': DateTime.now().toUtc().toIso8601String()},
      ifMatch: revision?.toString(),
    );
    await _flushQuietly();
  }

  Future<void> deletePlant(String plantId) async {
    await _database.removeDocument('plants', plantId);
    await _queue(
      id: 'plant-delete-$plantId',
      method: 'DELETE',
      path: '/v1/plants/$plantId',
      body: const {},
    );
    await _flushQuietly();
  }

  Future<void> logEvent({
    required String plantId,
    required CareEvent event,
  }) async {
    final id = event.id.isEmpty ? _uuid.v4() : event.id;
    final body = {
      'id': id,
      'eventType': event.eventType.wire,
      'occurredAt': event.occurredAt.toUtc().toIso8601String(),
      'note': event.note,
      'details': event.details,
    };
    await _database.saveDocument(
      collection: 'care_events',
      id: id,
      parentId: plantId,
      payload: jsonEncode(body),
    );
    await _queue(
      id: 'care-$id',
      method: 'POST',
      path: '/v1/plants/$plantId/care-events',
      body: body,
      idempotencyKey: id,
    );
    if (event.eventType == CareEventType.watered) {
      await _advanceWatering(plantId, event.occurredAt);
    }
    await _flushQuietly();
    if (event.eventType == CareEventType.watered) {
      final pending = await _database.pending();
      final saved = pending.every((operation) => operation.id != 'care-$id');
      if (saved) {
        await _pullPlants();
        await _pullReminders();
      }
    }
  }

  /// Moves the cached plant and its water reminder forward so today's chore
  /// disappears before the server copy comes back.
  Future<void> _advanceWatering(String plantId, DateTime occurredAt) async {
    final reminders = await _database.watchCollection('reminders').first;
    var intervalDays = 7;
    for (final row in reminders) {
      final json = _json(row.payload);
      if (json['plantId'] != plantId || json['taskType'] != 'water_check') {
        continue;
      }
      final interval = json['intervalDays'];
      if (interval is num && interval > 0) intervalDays = interval.toInt();
    }
    final next = occurredAt.add(Duration(days: intervalDays));
    final nextIso = next.toUtc().toIso8601String();
    final occurredIso = occurredAt.toUtc().toIso8601String();

    final plantRow = await _database.readDocument('plants', plantId);
    if (plantRow != null) {
      final json = _json(plantRow.payload);
      json['lastWateredAt'] = occurredIso;
      json['nextWaterCheckAt'] = nextIso;
      await _database.saveDocument(
        collection: 'plants',
        id: plantId,
        parentId: plantRow.parentId,
        payload: jsonEncode(json),
      );
    }

    final canonicalId = '${plantId}__water_check';
    for (final row in reminders) {
      final json = _json(row.payload);
      if (json['plantId'] != plantId || json['taskType'] != 'water_check') {
        continue;
      }
      if (row.id == canonicalId) {
        json['dueAt'] = nextIso;
        json['status'] = 'open';
        json['completedAt'] = occurredIso;
      } else if (json['status'] == null || json['status'] == 'open') {
        json['status'] = 'completed';
        json['completedAt'] = occurredIso;
      } else {
        continue;
      }
      await _database.saveDocument(
        collection: 'reminders',
        id: row.id,
        parentId: row.parentId,
        payload: jsonEncode(json),
      );
    }
  }

  Stream<List<CareEvent>> watchHistory(String plantId, {int limit = 50}) {
    unawaited(_pullCare(plantId));
    return _database
        .watchCollection('care_events', parentId: plantId)
        .map(
          (rows) => rows
              .take(limit)
              .map((row) => _careEvent(plantId, row.payload))
              .toList(),
        );
  }

  Stream<List<CareEvent>> watchHistoryOfType(
    String plantId,
    CareEventType eventType, {
    int limit = 50,
  }) {
    return watchHistory(plantId, limit: limit).map(
      (events) => [
        for (final event in events)
          if (event.eventType == eventType) event,
      ],
    );
  }

  Future<void> deleteEvent({
    required String plantId,
    required String eventId,
  }) async {
    await _database.removeDocument('care_events', eventId);
    await _queue(
      id: 'care-delete-$eventId',
      method: 'DELETE',
      path: '/v1/plants/$plantId/care-events/$eventId',
      body: const {},
    );
    await _flushQuietly();
  }

  Stream<List<Reminder>> watchOpen({int limit = 100}) {
    unawaited(_pullReminders());
    return _reminders().map(
      (items) => items
          .where((item) => item.status == ReminderStatus.open)
          .take(limit)
          .toList(),
    );
  }

  Stream<List<Reminder>> watchDue({DateTime? asOf, int limit = 100}) {
    final cutoff = asOf ?? DateTime.now();
    return watchOpen(limit: limit).map(
      (items) => items.where((item) => !item.dueAt.isAfter(cutoff)).toList(),
    );
  }

  Stream<List<Reminder>> watchForPlant(String plantId) {
    return watchOpen().map(
      (items) => items.where((item) => item.plantId == plantId).toList(),
    );
  }

  Future<void> addPlantToChores(String plantId) async {
    await _client.sendJson('POST', '/v1/plants/$plantId/chores');
    await _pullReminders();
  }

  Future<void> removePlantChores(Iterable<String> reminderIds) async {
    for (final id in reminderIds) {
      await deleteReminder(id);
    }
  }

  Future<String> createManual(Reminder reminder) async {
    final id = reminder.id.isEmpty ? _uuid.v4() : reminder.id;
    final body = {
      'id': id,
      'plantId': reminder.plantId,
      'taskType': reminder.taskType.wire,
      'title': reminder.title,
      'instructions': reminder.instructions,
      'dueAt': reminder.dueAt.toUtc().toIso8601String(),
      'priority': reminder.priority.wire,
      'intervalDays': reminder.schedule.intervalDays,
    };
    await _queue(
      id: 'reminder-$id',
      method: 'POST',
      path: '/v1/reminders',
      body: body,
      idempotencyKey: id,
    );
    await _flushQuietly();
    return id;
  }

  Future<void> completeReminder(String reminderId) =>
      _reminderAction(reminderId, 'complete');

  Future<void> skipReminder(String reminderId) =>
      _reminderAction(reminderId, 'skip');

  Future<void> cancelReminder(String reminderId) =>
      _reminderAction(reminderId, 'cancel');

  Future<void> snoozeReminder(String reminderId, {required DateTime until}) {
    return _queue(
      id: 'reminder-snooze-$reminderId',
      method: 'POST',
      path: '/v1/reminders/$reminderId/snooze',
      body: {'until': until.toUtc().toIso8601String()},
    ).then((_) => _flushQuietly());
  }

  Future<void> reopenReminder(String reminderId, {required DateTime dueAt}) {
    return _queue(
      id: 'reminder-reopen-$reminderId',
      method: 'POST',
      path: '/v1/reminders/$reminderId/reopen',
      body: {'dueAt': dueAt.toUtc().toIso8601String()},
    ).then((_) => _flushQuietly());
  }

  Future<void> deleteReminder(String reminderId) async {
    await _database.removeDocument('reminders', reminderId);
    await _queue(
      id: 'reminder-delete-$reminderId',
      method: 'DELETE',
      path: '/v1/reminders/$reminderId',
      body: const {},
    );
    await _flushQuietly();
  }

  Future<PlantPhoto> uploadPhoto({
    required String plantId,
    required Uint8List bytes,
    required String contentType,
    String? caption,
    DateTime? takenAt,
  }) async {
    final created = await _client.postBytes(
      '/v1/plants/$plantId/photos',
      bytes,
      contentType: contentType,
    );
    final id = created['id'] as String;
    final photo = PlantPhoto(
      id: id,
      storagePath: '$workerPhotoPrefix$id',
      caption: caption,
      takenAt: takenAt,
      sizeBytes: bytes.lengthInBytes,
      contentType: contentType,
      createdAt: _time(created['createdAt']),
    );
    await _database.saveDocument(
      collection: 'photos',
      id: id,
      parentId: plantId,
      payload: jsonEncode({
        'id': id,
        'contentType': contentType,
        'byteSize': bytes.lengthInBytes,
        'createdAt': created['createdAt'],
        'caption': caption,
      }),
    );
    return photo;
  }

  Stream<List<PlantPhoto>> watchPhotos(String plantId) {
    unawaited(_pullPhotos(plantId));
    return _database
        .watchCollection('photos', parentId: plantId)
        .map((rows) => rows.map((row) => _photo(row.payload)).toList());
  }

  Future<void> deletePhoto({
    required String plantId,
    required PlantPhoto photo,
  }) async {
    await _database.removeDocument('photos', photo.id);
    await _client.sendJson('DELETE', '/v1/photos/${photo.id}');
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.postBytes('/v1/me/avatar', bytes, contentType: contentType);
    return workerAvatarPath;
  }

  Future<void> syncProfile({String? displayName, String? email}) {
    return _client.sendJson(
      'PUT',
      '/v1/me',
      body: {'displayName': ?displayName, 'email': ?email},
    );
  }

  Future<void> registerDeviceToken(String token, {String? platform}) async {
    await _database.saveDocument(
      collection: 'tokens',
      id: token,
      payload: jsonEncode({'token': token}),
    );
    await _client.sendJson(
      'POST',
      '/v1/me/devices',
      body: {'token': token, 'platform': ?platform},
    );
  }

  Future<void> removeDeviceToken(String token) async {
    await _database.removeDocument('tokens', token);
    await _client.sendJson('DELETE', '/v1/me/devices', body: {'token': token});
  }

  /// Marks this account's Worker rows deleted and drops the local copy.
  ///
  /// Must run while the Firebase token is still valid. The caller then deletes
  /// the Auth user.
  Future<void> deleteAccount() async {
    await _client.sendJson('DELETE', '/v1/me');
    await _database.clearPersonalData();
  }

  Stream<List<String>> watchDeviceTokens() {
    return _database
        .watchCollection('tokens')
        .map((rows) => [for (final row in rows) row.id]);
  }

  Future<Species?> getSpecies(String speciesId) async {
    try {
      final json = await _client.getJson('/v1/species/$speciesId');
      await _database.saveDocument(
        collection: 'species',
        id: speciesId,
        payload: jsonEncode(json),
      );
      return _species(json);
    } on NotFoundException {
      return null;
    }
  }

  Stream<Species?> watchSpecies(String speciesId) async* {
    final cached = await _database.readDocument('species', speciesId);
    if (cached != null) yield _species(_json(cached.payload));
    yield await getSpecies(speciesId);
  }

  Future<List<CareProfile>> getCareProfiles(String speciesId) async {
    final species = await getSpecies(speciesId);
    if (species == null) return const [];
    final cached = await _database.readDocument('species', speciesId);
    if (cached == null) return const [];
    final profiles = _json(cached.payload)['careProfiles'];
    if (profiles is! List) return const [];
    return [
      for (final profile in profiles)
        if (profile is Map)
          CareProfile(
            id: profile['id'] as String? ?? speciesId,
            label: profile['name'] as String? ?? 'Care profile',
            tasks: [
              for (final task in (profile['tasks'] as List? ?? const []))
                if (task is Map<String, dynamic>) CareProfileTask.fromMap(task),
            ],
          ),
    ];
  }

  Future<List<SpeciesSource>> getSources(String speciesId) async {
    final species = await getSpecies(speciesId);
    if (species == null) return const [];
    return [
      SpeciesSource(id: 'catalog', provider: 'catalog', externalId: speciesId),
    ];
  }

  Future<SpeciesSearchResult> search(
    String query, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    final json = await _client.getJson(
      '/v1/species',
      query: {
        'q': query,
        if (filters.ranks.isNotEmpty)
          'rank': [for (final rank in filters.ranks) rank.wire].join(','),
        if (filters.families.isNotEmpty) 'family': filters.families.join(','),
        if (filters.edible) 'edible': 'true',
        if (filters.vegetable) 'vegetable': 'true',
      },
    );
    final results = json['results'];
    return SpeciesSearchResult(
      attribution: json['attribution'] as String? ?? 'Raíces catalog',
      candidates: results is List
          ? [
              for (final item in results)
                if (item is Map<String, dynamic>)
                  SpeciesCandidate(
                    speciesId: item['id'] as String? ?? '',
                    scientificName: item['scientificName'] as String? ?? '',
                    commonName:
                        (item['commonNames'] is List &&
                            (item['commonNames'] as List).isNotEmpty)
                        ? (item['commonNames'] as List).first as String?
                        : null,
                    family: item['family'] as String?,
                    imageUrl: item['imageUrl'] as String?,
                    trefleSlug: item['trefleSlug'] as String?,
                    dataCompleteness: item['dataCompleteness'] is num
                        ? (item['dataCompleteness'] as num).toInt()
                        : null,
                  ),
            ]
          : const [],
    );
  }

  Future<String> resolve({String? speciesId, String? trefleSlug}) async {
    final json = await _client.sendJson(
      'POST',
      '/v1/species/resolve',
      body: {'speciesId': ?speciesId, 'trefleSlug': ?trefleSlug},
    );
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const UnexpectedException('The catalog returned no species id.');
    }
    return id;
  }

  Future<void> _pullPlants() async {
    try {
      final json = await _client.getJson('/v1/plants');
      final results = json['results'];
      if (results is! List) return;
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id'] as String;
        await _database.saveDocument(
          collection: 'plants',
          id: id,
          parentId: _spot(item['gardenId'] as String?),
          payload: jsonEncode(item),
        );
      }
    } on NetworkException {
      return;
    }
  }

  Future<void> _pullCare(String plantId) async {
    try {
      final json = await _client.getJson('/v1/plants/$plantId/care-events');
      final results = json['results'];
      if (results is! List) return;
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        await _database.saveDocument(
          collection: 'care_events',
          id: item['id'] as String,
          parentId: plantId,
          payload: jsonEncode(item),
        );
      }
    } on NetworkException {
      return;
    }
  }

  Future<void> _pullReminders() async {
    try {
      final json = await _client.getJson(
        '/v1/reminders',
        query: {'status': 'any'},
      );
      final results = json['results'];
      if (results is! List) return;
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        await _database.saveDocument(
          collection: 'reminders',
          id: item['id'] as String,
          parentId: item['plantId'] as String?,
          payload: jsonEncode(item),
        );
      }
    } on NetworkException {
      return;
    }
  }

  Future<void> _pullPhotos(String plantId) async {
    try {
      final json = await _client.getJson('/v1/plants/$plantId/photos');
      final results = json['results'];
      if (results is! List) return;
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        await _database.saveDocument(
          collection: 'photos',
          id: item['id'] as String,
          parentId: plantId,
          payload: jsonEncode(item),
        );
      }
    } on NetworkException {
      return;
    }
  }

  Stream<List<Reminder>> _reminders() {
    return _database
        .watchCollection('reminders')
        .map((rows) => rows.map((row) => _reminder(row.payload)).toList());
  }

  Future<void> _reminderAction(String reminderId, String action) async {
    await _queue(
      id: 'reminder-$action-$reminderId',
      method: 'POST',
      path: '/v1/reminders/$reminderId/$action',
      body: const {},
    );
    await _flushQuietly();
  }

  Future<void> _queue({
    required String id,
    required String method,
    required String path,
    required Map<String, Object?> body,
    String? idempotencyKey,
    String? ifMatch,
  }) {
    return _database.enqueue(
      id: id,
      method: method,
      path: path,
      body: jsonEncode({'body': body, 'ifMatch': ifMatch}),
      idempotencyKey: idempotencyKey,
    );
  }

  Future<void> _flushQuietly() async {
    try {
      await _sync.flush();
    } on NetworkException {
      return;
    }
  }

  String _gardenId(String spot) => '$_user--$spot';

  String _gardenName(String spot) => spot.replaceAll('_', ' ');

  String? _spot(String? gardenId) {
    if (gardenId == null) return null;
    final prefix = '$_user--';
    if (gardenId.startsWith(prefix)) return gardenId.substring(prefix.length);
    return gardenId;
  }

  Plant _plant(String payload) {
    final json = _json(payload);
    final archivedAt = json['archivedAt'];
    return Plant(
      id: json['id'] as String,
      speciesId: (json['speciesId'] as String?) ?? 'unknown',
      displayName:
          (json['nickname'] as String?) ??
          (json['speciesName'] as String?) ??
          'Plant',
      gardenId: _spot(json['gardenId'] as String?),
      locationType: LocationType.fromWire(json['locationType']),
      speciesNameSnapshot: json['speciesName'] as String?,
      acquiredAt: _time(json['acquiredAt']),
      plantedAt: _time(json['plantedAt']),
      status: PlantStatus(
        health: PlantHealth.fromWire(json['health']),
        isArchived: archivedAt != null,
      ),
      currentCare: PlantCurrentCare(
        lastWateredAt: _time(json['lastWateredAt']),
        lastFertilizedAt: _time(json['lastFertilizedAt']),
        lastPestInspectionAt: _time(json['lastPestCheckAt']),
      ),
      nextActions: PlantNextActions(
        nextWaterCheckAt: _time(json['nextWaterCheckAt']),
        nextFertilizeAt: _time(json['nextFertilizeAt']),
        nextPestCheckAt: _time(json['nextPestCheckAt']),
      ),
      createdAt: _time(json['createdAt']),
      updatedAt: _time(json['updatedAt']),
    );
  }

  CareEvent _careEvent(String plantId, String payload) {
    final json = _json(payload);
    return CareEvent(
      id: json['id'] as String? ?? '',
      eventType: CareEventType.fromWire(json['eventType']),
      occurredAt: _time(json['occurredAt']) ?? DateTime.now(),
      note: json['note'] as String?,
      details: json['details'] is Map
          ? (json['details'] as Map).cast<String, dynamic>()
          : const {},
      createdAt: _time(json['createdAt']),
    );
  }

  Reminder _reminder(String payload) {
    final json = _json(payload);
    return Reminder(
      id: json['id'] as String,
      plantId: json['plantId'] as String? ?? '',
      taskType: ReminderTaskType.fromWire(json['taskType']),
      title: json['title'] as String? ?? 'Care task',
      dueAt: _time(json['dueAt']) ?? DateTime.now(),
      speciesId: json['speciesId'] as String?,
      instructions: json['instructions'] as String?,
      status: ReminderStatus.fromWire(json['status']),
      priority: ReminderPriority.fromWire(json['priority']),
      schedule: ReminderSchedule(
        source: ScheduleSource.fromWire(json['scheduleSource']),
        intervalDays: json['intervalDays'] as int?,
        mode: json['intervalDays'] == null
            ? ScheduleMode.manual
            : ScheduleMode.interval,
      ),
      completedAt: _time(json['completedAt']),
      snoozedUntil: _time(json['snoozedUntil']),
      createdAt: _time(json['createdAt']),
      updatedAt: _time(json['updatedAt']),
    );
  }

  PlantPhoto _photo(String payload) {
    final json = _json(payload);
    final id = json['id'] as String;
    return PlantPhoto(
      id: id,
      storagePath: '$workerPhotoPrefix$id',
      caption: json['caption'] as String?,
      sizeBytes: json['byteSize'] as int?,
      contentType: json['contentType'] as String?,
      createdAt: _time(json['createdAt']),
    );
  }

  Species _species(Map<String, dynamic> json) {
    final names = json['commonNames'];
    return Species(
      id: json['id'] as String? ?? '',
      scientificName: json['scientificName'] as String? ?? '',
      commonNames: names is List
          ? [for (final name in names) '$name']
          : const [],
      commonName: names is List && names.isNotEmpty ? '${names.first}' : null,
      plantGroups: json['plantGroups'] is List
          ? [for (final group in json['plantGroups'] as List) '$group']
          : const [],
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> _json(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return const {};
  }

  DateTime? _time(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
