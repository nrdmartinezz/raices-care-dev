import 'package:flutter/foundation.dart';

import '../../features/care/data/care_event_repository.dart';
import '../../features/care/data/reminder_repository.dart';
import '../../features/care/domain/care_event.dart';
import '../../features/care/domain/reminder.dart';
import '../../features/onboarding/data/avatar_repository.dart';
import '../../features/photos/data/photo_repository.dart';
import '../../features/photos/domain/plant_photo.dart';
import '../../features/plants/data/plant_repository.dart';
import '../../features/plants/data/species_repository.dart';
import '../../features/plants/domain/care_profile.dart';
import '../../features/plants/domain/plant.dart';
import '../../features/plants/domain/search_filters.dart';
import '../../features/plants/domain/species.dart';
import '../../features/settings/data/user_settings_repository.dart';
import 'worker_backend.dart';

class WorkerPlantRepository extends PlantRepository {
  WorkerPlantRepository({
    required super.firestore,
    required super.userId,
    required this.backend,
  });

  final WorkerBackend backend;

  @override
  Stream<List<Plant>> watchActivePlants() => backend.watchActivePlants();

  @override
  Stream<List<Plant>> watchPlantsInGarden(String gardenId) =>
      backend.watchPlantsInGarden(gardenId);

  @override
  Stream<Plant?> watchPlant(String plantId) => backend.watchPlant(plantId);

  @override
  Future<Plant?> getPlant(String plantId) => backend.getPlant(plantId);

  @override
  Future<String> createPlant(Plant plant) => backend.createPlant(plant);

  @override
  Future<void> updatePlant(Plant plant) => backend.updatePlant(plant);

  @override
  Future<void> archivePlant(String plantId) => backend.archivePlant(plantId);

  @override
  Future<void> deletePlant(String plantId) => backend.deletePlant(plantId);
}

class WorkerCareEventRepository extends CareEventRepository {
  WorkerCareEventRepository({
    required super.firestore,
    required super.userId,
    required this.backend,
  });

  final WorkerBackend backend;

  @override
  Future<void> logEvent({required String plantId, required CareEvent event}) =>
      backend.logEvent(plantId: plantId, event: event);

  @override
  Stream<List<CareEvent>> watchHistory(String plantId, {int limit = 50}) =>
      backend.watchHistory(plantId, limit: limit);

  @override
  Stream<List<CareEvent>> watchHistoryOfType(
    String plantId,
    CareEventType eventType, {
    int limit = 50,
  }) => backend.watchHistoryOfType(plantId, eventType, limit: limit);

  @override
  Future<void> deleteEvent({
    required String plantId,
    required String eventId,
  }) => backend.deleteEvent(plantId: plantId, eventId: eventId);
}

class WorkerReminderRepository extends ReminderRepository {
  WorkerReminderRepository({
    required super.firestore,
    required super.userId,
    required this.backend,
  });

  final WorkerBackend backend;

  @override
  Stream<List<Reminder>> watchOpen({int limit = 100}) =>
      backend.watchOpen(limit: limit);

  @override
  Stream<List<Reminder>> watchDue({DateTime? asOf, int limit = 100}) =>
      backend.watchDue(asOf: asOf, limit: limit);

  @override
  Stream<List<Reminder>> watchForPlant(String plantId) =>
      backend.watchForPlant(plantId);

  @override
  Future<void> addPlantToChores({
    required String plantId,
    required String? speciesId,
    required List<CareProfile> profiles,
  }) => backend.addPlantToChores(plantId);

  @override
  Future<void> removePlantChores(Iterable<String> reminderIds) =>
      backend.removePlantChores(reminderIds);

  @override
  Future<String> createManual(Reminder reminder) =>
      backend.createManual(reminder);

  @override
  Future<void> complete(String reminderId, {DateTime? completedAt}) =>
      backend.completeReminder(reminderId);

  @override
  Future<void> skip(String reminderId) => backend.skipReminder(reminderId);

  @override
  Future<void> cancel(String reminderId) => backend.cancelReminder(reminderId);

  @override
  Future<void> snooze(String reminderId, {required DateTime until}) =>
      backend.snoozeReminder(reminderId, until: until);

  @override
  Future<void> reopen(String reminderId, {required DateTime dueAt}) =>
      backend.reopenReminder(reminderId, dueAt: dueAt);

  @override
  Future<void> delete(String reminderId) => backend.deleteReminder(reminderId);
}

class WorkerPhotoRepository extends PhotoRepository {
  WorkerPhotoRepository({
    required super.firestore,
    required super.functions,
    required super.userId,
    required this.backend,
  });

  final WorkerBackend backend;

  @override
  Future<PlantPhoto> uploadPhoto({
    required String plantId,
    required Uint8List bytes,
    required String contentType,
    String? caption,
    DateTime? takenAt,
  }) => backend.uploadPhoto(
    plantId: plantId,
    bytes: bytes,
    contentType: contentType,
    caption: caption,
    takenAt: takenAt,
  );

  @override
  Stream<List<PlantPhoto>> watchPhotos(String plantId) =>
      backend.watchPhotos(plantId);

  @override
  Future<void> deletePhoto({
    required String plantId,
    required PlantPhoto photo,
  }) => backend.deletePhoto(plantId: plantId, photo: photo);
}

class WorkerSpeciesRepository extends SpeciesRepository {
  WorkerSpeciesRepository({
    required super.firestore,
    required super.functions,
    required this.backend,
  });

  final WorkerBackend backend;

  @override
  Future<Species?> getSpecies(String speciesId) =>
      backend.getSpecies(speciesId);

  @override
  Stream<Species?> watchSpecies(String speciesId) =>
      backend.watchSpecies(speciesId);

  @override
  Future<List<CareProfile>> getCareProfiles(String speciesId) =>
      backend.getCareProfiles(speciesId);

  @override
  Future<List<SpeciesSource>> getSources(String speciesId) =>
      backend.getSources(speciesId);

  @override
  Future<SpeciesSearchResult> search(
    String query, {
    SearchFilters filters = const SearchFilters(),
  }) => backend.search(query, filters: filters);

  @override
  Future<String> resolve({String? speciesId, String? trefleSlug}) =>
      backend.resolve(speciesId: speciesId, trefleSlug: trefleSlug);
}

class WorkerAvatarRepository extends AvatarRepository {
  WorkerAvatarRepository({
    required super.functions,
    required super.userId,
    required this.backend,
    this.onUploaded,
  });

  final WorkerBackend backend;
  final void Function(String storagePath)? onUploaded;

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = await backend.uploadAvatar(
      bytes: bytes,
      contentType: contentType,
    );
    onUploaded?.call(path);
    return path;
  }
}

class WorkerUserSettingsRepository extends UserSettingsRepository {
  WorkerUserSettingsRepository({
    required super.firestore,
    required super.messaging,
    required super.userId,
    required this.backend,
  });

  final WorkerBackend backend;

  @override
  Stream<List<String>> watchDeviceTokens() => backend.watchDeviceTokens();

  @override
  Future<void> registerDeviceToken(String token) =>
      backend.registerDeviceToken(token, platform: _platform);

  @override
  Future<void> removeDeviceToken(String token) =>
      backend.removeDeviceToken(token);

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }
}
