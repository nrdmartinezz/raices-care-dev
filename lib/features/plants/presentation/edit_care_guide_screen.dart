import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../care/domain/care_task_type.dart';
import '../data/plant_repository.dart';
import '../data/species_repository.dart';
import '../domain/care_profile.dart';
import '../domain/plant.dart';
import '../domain/species.dart';
import 'care_labels.dart';

/// The gardener's care guide for one plant. The catalog fills the blanks
/// until they save, and that save stays on this plant.
class EditCareGuideScreen extends ConsumerStatefulWidget {
  const EditCareGuideScreen({super.key, required this.plantId});

  final String plantId;

  @override
  ConsumerState<EditCareGuideScreen> createState() =>
      _EditCareGuideScreenState();
}

class _EditCareGuideScreenState extends ConsumerState<EditCareGuideScreen> {
  final _light = TextEditingController();
  final _pests = TextEditingController();
  final _feeding = TextEditingController();
  final _pruning = TextEditingController();
  final _humidity = TextEditingController();
  final _repotting = TextEditingController();
  var _ready = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _light.dispose();
    _pests.dispose();
    _feeding.dispose();
    _pruning.dispose();
    _humidity.dispose();
    _repotting.dispose();
    super.dispose();
  }

  void _load(PlantCareGuide guide) {
    if (_ready) return;
    _light.text = guide.light ?? '';
    _pests.text = guide.pests ?? '';
    _feeding.text = guide.feeding ?? '';
    _pruning.text = guide.pruning ?? '';
    _humidity.text = guide.humidity ?? '';
    _repotting.text = guide.repotting ?? '';
    _ready = true;
  }

  Future<void> _save(String plantId) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    String? text(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    try {
      await ref.read(plantRepositoryProvider).patchPlant(plantId, {
        'careGuide': PlantCareGuide(
          light: text(_light),
          pests: text(_pests),
          feeding: text(_feeding),
          pruning: text(_pruning),
          humidity: text(_humidity),
          repotting: text(_repotting),
        ).toJson(),
      });
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
      final speciesAsync = ref.watch(speciesProvider(plant.speciesId));
      final profilesAsync = ref.watch(careProfilesProvider(plant.speciesId));
      final saved = plant.careGuide;
      final catalogReady =
          saved != null ||
          ((speciesAsync.hasValue || speciesAsync.hasError) &&
              (profilesAsync.hasValue || profilesAsync.hasError));
      if (catalogReady) {
        final guide =
            saved ??
            suggestCareGuide(speciesAsync.value, profilesAsync.value);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _ready) return;
          setState(() => _load(guide));
        });
      }
    }

    return ShellScrollView(
      child: plant == null || !_ready
          ? const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Care guide',
                  style: AppText.display.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'These notes belong to this plant. The catalog fills them in until you save your own.',
                  style: AppText.body.copyWith(color: AppColors.body),
                ),
                const SizedBox(height: 20),
                _line('Light requirements', _light),
                _line('Pests to watch for', _pests),
                _line('Feeding', _feeding),
                _line('Pruning schedule', _pruning),
                _line('Humidity', _humidity),
                _line('Repotting schedule', _repotting),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: AppText.body.copyWith(
                      color: AppColors.terracottaBright,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : () => _save(plant.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    ),
                  ),
                  child: Text(
                    _saving ? 'Saving…' : 'Save care guide',
                    style: AppText.subtitleBold.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _line(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label.copyWith(color: AppColors.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Catalog text used until the gardener saves a guide of their own.
PlantCareGuide suggestCareGuide(
  Species? species,
  List<CareProfile>? profiles,
) {
  String? task(ReminderTaskType type) {
    for (final profile in profiles ?? const <CareProfile>[]) {
      for (final item in profile.tasks) {
        if (item.taskType != type) continue;
        final text = (item.instructions ?? item.title).trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  final light = species?.growth.light;
  return PlantCareGuide(
    light: light == null ? null : lightLabel(light),
    pests: task(ReminderTaskType.pestCheck),
    feeding: task(ReminderTaskType.fertilize),
    pruning: task(ReminderTaskType.prune),
    humidity: humidityLabel(species?.growth.atmosphericHumidity),
    repotting: task(ReminderTaskType.repot),
  );
}
