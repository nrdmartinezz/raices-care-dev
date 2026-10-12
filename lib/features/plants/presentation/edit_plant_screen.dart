import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../home/data/home_providers.dart';
import '../../care/data/care_event_repository.dart';
import '../../care/domain/care_event.dart';
import '../../photos/data/photo_repository.dart';
import '../../photos/domain/plant_photo.dart';
import '../../photos/presentation/photo_picker.dart';
import '../data/observation_repository.dart';
import '../data/plant_repository.dart';
import '../data/species_repository.dart';
import '../domain/observation.dart';
import '../domain/plant.dart';
import 'care_labels.dart';

/// Edits one plant's own details. The care guide has its own screen.
///
/// Photos, journal notes, and watering entries are their own Worker records
/// and save as they change. The button saves the plant row.
class EditPlantScreen extends ConsumerStatefulWidget {
  const EditPlantScreen({super.key, required this.plantId});

  final String plantId;

  @override
  ConsumerState<EditPlantScreen> createState() => _EditPlantScreenState();
}

class _EditPlantScreenState extends ConsumerState<EditPlantScreen> {
  final _name = TextEditingController();
  final _scientific = TextEditingController();
  var _ready = false;
  var _saving = false;
  var _ageEdited = false;
  var _years = 0;
  var _months = 0;
  DateTime? _planted;
  GrowingMethod _method = GrowingMethod.container;
  PlantHealth _health = PlantHealth.unknown;
  String? _coverId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _scientific.dispose();
    super.dispose();
  }

  void _load(Plant plant) {
    if (_ready) return;
    final now = DateTime.now();
    final anchor =
        plant.ageFrom ?? plant.plantedAt ?? plant.acquiredAt ?? plant.createdAt;
    final parts = anchor == null
        ? (years: 0, months: 0)
        : ageParts(anchor, now);
    _name.text = plant.displayName;
    _scientific.text = plant.scientificName ?? '';
    _planted = plant.plantedAt;
    _method = switch (plant.growingMethod) {
      GrowingMethod.raisedBed => GrowingMethod.raisedBed,
      GrowingMethod.inGround => GrowingMethod.inGround,
      _ => GrowingMethod.container,
    };
    _health = plant.status.health;
    _coverId = plant.coverPhotoId;
    _years = parts.years;
    _months = parts.months;
    _ready = true;
  }

  Future<void> _save(Plant plant) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final scientific = _scientific.text.trim();
    final changes = <String, Object?>{
      'nickname': name,
      'scientificName': scientific.isEmpty ? null : scientific,
      'plantedAt': _planted?.toUtc().toIso8601String(),
      'growingMethod': _method.wire,
      'health': _health.wire,
      'coverPhotoId': _coverId,
    };
    if (_ageEdited) {
      changes['ageFrom'] = ageAnchorFromParts(
        now: DateTime.now(),
        years: _years,
        months: _months,
      ).toUtc().toIso8601String();
    }
    try {
      await ref.read(plantRepositoryProvider).patchPlant(plant.id, changes);
      if (mounted) context.pop();
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Something went wrong.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(plantProvider(widget.plantId)).value;
    if (plant != null && !_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _ready) return;
        setState(() => _load(plant));
      });
    }

    return ShellScrollView(
      child: plant == null || !_ready
          ? const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          : _form(plant),
    );
  }

  Widget _form(Plant plant) {
    final species = ref.watch(speciesProvider(plant.speciesId)).value;
    final catalogName =
        species?.scientificName ?? plant.speciesNameSnapshot ?? '';
    final photos =
        ref.watch(plantPhotosProvider(plant.id)).value ?? const <PlantPhoto>[];
    final notes =
        ref.watch(plantObservationsProvider(plant.id)).value ??
        const <Observation>[];
    final waterings =
        ref.watch(wateringLogProvider(plant.id)).value ?? const <CareEvent>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit plant details',
          style: AppText.display.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Text(
          'A little update for your growing companion.',
          style: AppText.body.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: 20),
        _Photos(
          plantId: plant.id,
          photos: photos,
          coverId: _coverId,
          onCover: (id) => setState(() => _coverId = id),
          onError: (message) => setState(() => _error = message),
        ),
        const SizedBox(height: 20),
        _Card(
          title: 'Plant information',
          children: [
            _Field(
              label: 'Name',
              child: TextField(
                controller: _name,
                decoration: _inputDecoration(),
              ),
            ),
            _Field(
              label: 'Scientific name',
              child: TextField(
                controller: _scientific,
                decoration: _inputDecoration(
                  hint: catalogName.isEmpty ? null : catalogName,
                ),
              ),
            ),
            _Field(
              label: 'Age',
              child: Row(
                children: [
                  Expanded(
                    child: _Menu<int>(
                      value: _years,
                      items: [for (var year = 0; year <= 40; year++) year],
                      label: (year) => year == 1 ? '1 yr' : '$year yrs',
                      onChanged: (year) => setState(() {
                        _years = year;
                        _ageEdited = true;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Menu<int>(
                      value: _months,
                      items: [for (var month = 0; month <= 11; month++) month],
                      label: (month) => month == 1 ? '1 mo' : '$month mos',
                      onChanged: (month) => setState(() {
                        _months = month;
                        _ageEdited = true;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            _Field(
              label: 'Planted',
              child: _DateField(
                value: _planted,
                onPick: (day) => setState(() => _planted = day),
              ),
            ),
            _Field(
              label: 'Planting type',
              child: _Menu<GrowingMethod>(
                value: _method,
                items: const [
                  GrowingMethod.container,
                  GrowingMethod.raisedBed,
                  GrowingMethod.inGround,
                ],
                label: _methodLabel,
                onChanged: (method) => setState(() => _method = method),
              ),
            ),
            _Field(
              label: 'State',
              child: _Menu<PlantHealth>(
                value: _health,
                items: const [
                  PlantHealth.healthy,
                  PlantHealth.needsAttention,
                  PlantHealth.recovering,
                  PlantHealth.unknown,
                ],
                label: _healthLabel,
                onChanged: (health) => setState(() => _health = health),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Notes(plantId: plant.id, notes: notes),
        const SizedBox(height: 16),
        _WateringLog(plantId: plant.id, events: waterings),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: AppText.body.copyWith(color: AppColors.terracottaBright),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : () => _save(plant),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.terracotta,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
          ),
          child: Text(
            _saving ? 'Saving…' : 'Save changes',
            style: AppText.subtitleBold.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Photos, notes, and watering save as you change them.',
            style: AppText.caption.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _Photos extends ConsumerWidget {
  const _Photos({
    required this.plantId,
    required this.photos,
    required this.coverId,
    required this.onCover,
    required this.onError,
  });

  final String plantId;
  final List<PlantPhoto> photos;
  final String? coverId;
  final ValueChanged<String?> onCover;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plant photos', style: AppText.title.copyWith(color: AppColors.ink)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final photo in photos) ...[
                _PhotoTile(
                  photo: photo,
                  isCover: photo.id == coverId,
                  onCover: () => onCover(photo.id),
                  onDelete: () async {
                    try {
                      await ref.read(photoRepositoryProvider).deletePhoto(
                        plantId: plantId,
                        photo: photo,
                      );
                      if (photo.id == coverId) onCover(null);
                    } on AppException catch (error) {
                      onError(error.message);
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
              _AddPhoto(
                onTap: () async {
                  try {
                    final picked = await pickGardenPhoto(context);
                    if (picked == null) return;
                    final photo = await ref
                        .read(photoRepositoryProvider)
                        .uploadPhoto(
                          plantId: plantId,
                          bytes: picked.bytes,
                          contentType: picked.contentType,
                        );
                    if (coverId == null) onCover(photo.id);
                  } on AppException catch (error) {
                    onError(error.message);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({
    required this.photo,
    required this.isCover,
    required this.onCover,
    required this.onDelete,
  });

  final PlantPhoto photo;
  final bool isCover;
  final VoidCallback onCover;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(plantCoverImageProvider(photo.storagePath));
    return GestureDetector(
      onTap: onCover,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            child: Image(
              image: image,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          if (isCover)
            const Positioned(
              left: 6,
              bottom: 6,
              child: _Badge(label: 'Profile photo'),
            ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.terracotta,
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhoto extends StatelessWidget {
  const _AddPhoto({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: Container(
        width: 96,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(color: AppColors.terracottaBright),
        ),
        child: Text(
          'Add image',
          style: AppText.label.copyWith(color: AppColors.terracotta),
        ),
      ),
    );
  }
}

class _Notes extends ConsumerWidget {
  const _Notes({required this.plantId, required this.notes});

  final String plantId;
  final List<Observation> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: 'Journal',
      trailing: TextButton(
        onPressed: () async {
          final text = await _askText(context, title: 'New note');
          if (text == null || text.trim().isEmpty) return;
          await ref
              .read(observationRepositoryProvider)
              .add(plantId: plantId, note: text);
        },
        child: const Text('Add'),
      ),
      children: [
        if (notes.isEmpty)
          Text(
            'No notes yet.',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        for (final note in notes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(note.note, style: AppText.body.copyWith(color: AppColors.ink)),
            subtitle: Text(
              writtenLabel(note.observedAt, now: DateTime.now()),
              style: AppText.caption.copyWith(color: AppColors.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () async {
                    final text = await _askText(
                      context,
                      title: 'Edit note',
                      initial: note.note,
                    );
                    if (text == null) return;
                    await ref.read(observationRepositoryProvider).update(
                      plantId: plantId,
                      observationId: note.id,
                      note: text,
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  onPressed: () => ref.read(observationRepositoryProvider).delete(
                    plantId: plantId,
                    observationId: note.id,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WateringLog extends ConsumerWidget {
  const _WateringLog({required this.plantId, required this.events});

  final String plantId;
  final List<CareEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: 'Watering log',
      trailing: TextButton(
        onPressed: () async {
          final when = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1990),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (when == null) return;
          await ref.read(careEventRepositoryProvider).logEvent(
            plantId: plantId,
            event: CareEvent(
              id: const Uuid().v4(),
              eventType: CareEventType.watered,
              occurredAt: when,
            ),
          );
        },
        child: const Text('Add'),
      ),
      children: [
        if (events.isEmpty)
          Text(
            'No waterings yet.',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        for (final event in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              writtenLabel(event.occurredAt, now: DateTime.now()),
              style: AppText.body.copyWith(color: AppColors.ink),
            ),
            subtitle: event.note == null
                ? null
                : Text(event.note!, style: AppText.caption),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () async {
                    final when = await showDatePicker(
                      context: context,
                      initialDate: event.occurredAt,
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (when == null) return;
                    await ref.read(careEventRepositoryProvider).updateEvent(
                      plantId: plantId,
                      event: CareEvent(
                        id: event.id,
                        eventType: event.eventType,
                        occurredAt: when,
                        note: event.note,
                        details: event.details,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  onPressed: () => ref.read(careEventRepositoryProvider).deleteEvent(
                    plantId: plantId,
                    eventId: event.id,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppText.title.copyWith(color: AppColors.ink)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label.copyWith(color: AppColors.muted)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: _inputDecoration(),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(label(item))),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onPick});

  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? 'Not set'
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1990),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration(),
        child: Text(label, style: AppText.body.copyWith(color: AppColors.ink)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppText.caption.copyWith(color: AppColors.ink)),
    );
  }
}

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.canvas,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

String _methodLabel(GrowingMethod method) => switch (method) {
  GrowingMethod.container => 'Pot',
  GrowingMethod.raisedBed => 'Raised bed',
  GrowingMethod.inGround => 'In-ground',
  GrowingMethod.hydroponic => 'Hydroponic',
  GrowingMethod.other => 'Other',
};

String _healthLabel(PlantHealth health) => switch (health) {
  PlantHealth.healthy => 'Thriving',
  PlantHealth.needsAttention => 'Needs care',
  PlantHealth.recovering => 'Recovering',
  PlantHealth.unknown => 'Not set',
};

Future<String?> _askText(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'What did you notice?'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
