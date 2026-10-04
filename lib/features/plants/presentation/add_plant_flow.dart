import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../photos/data/photo_repository.dart';
import '../../photos/presentation/photo_picker.dart';
import '../data/plant_repository.dart';
import '../data/species_repository.dart';
import '../domain/care_profile.dart';
import '../domain/plant.dart';

/// Search, resolve, then create. Shared by onboarding and `/add-plant`.
///
/// [speciesRepository.resolve] runs when a result is chosen, before
/// [PlantRepository.createPlant], so `onPlantCreated` can seed reminders.
/// The UI does not wait for those reminders.
class AddPlantFlow extends ConsumerStatefulWidget {
  const AddPlantFlow({
    super.key,
    required this.explain,
    this.eyebrow = 'NEW SPROUT',
    this.title = 'Add a plant',
    this.onClose,
    this.onCreated,
    this.onSkip,
  });

  /// Beginners get one sentence on light and on location.
  final bool explain;
  final String eyebrow;
  final String title;
  final VoidCallback? onClose;

  /// After the plant document is written. Onboarding finishes the profile
  /// here; the add-plant route leaves.
  final Future<void> Function()? onCreated;

  /// Onboarding only. Leaves without creating a plant.
  final Future<void> Function()? onSkip;

  @override
  ConsumerState<AddPlantFlow> createState() => _AddPlantFlowState();
}

enum _Phase { search, details }

class _AddPlantFlowState extends ConsumerState<AddPlantFlow> {
  static const _uuid = Uuid();

  final _query = TextEditingController();
  final _nickname = TextEditingController();

  var _phase = _Phase.search;
  var _busy = false;
  var _resolving = false;
  var _searched = false;
  var _sparse = false;
  var _plantSaved = false;
  String? _error;
  String? _attribution;
  String? _speciesId;
  String? _plantId;
  String? _coverPath;
  List<SpeciesCandidate> _results = const [];
  SpeciesCandidate? _candidate;
  PickedGardenPhoto? _photo;
  LocationType? _location;
  GrowingMethod? _method;
  SunExposure? _light;

  @override
  void dispose() {
    _query.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Enter at least 2 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(speciesRepositoryProvider).search(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = result.candidates;
        _attribution = result.attribution;
        _searched = true;
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _choose(SpeciesCandidate candidate) async {
    setState(() {
      _busy = true;
      _resolving = true;
      _error = null;
    });
    try {
      final species = ref.read(speciesRepositoryProvider);
      final speciesId = await species.resolve(
        speciesId: candidate.speciesId.isEmpty ? null : candidate.speciesId,
        trefleSlug: candidate.trefleSlug,
      );
      final sparse = await _scheduleIsDefault(species, speciesId);
      if (!mounted) {
        return;
      }
      _nickname.text = candidate.displayName;
      setState(() {
        _speciesId = speciesId;
        _candidate = candidate;
        _sparse = sparse;
        _phase = _Phase.details;
        _plantId = null;
        _coverPath = null;
        _plantSaved = false;
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _resolving = false;
        });
      }
    }
  }

  Future<bool> _scheduleIsDefault(
    SpeciesRepository species,
    String speciesId,
  ) async {
    try {
      final profiles = await species.getCareProfiles(speciesId);
      return profiles.any(
        (CareProfile profile) =>
            profile.tasks.any((task) => task.isDefaultCadence),
      );
    } on AppException {
      return false;
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await pickGardenPhoto(context);
      if (picked != null && mounted) {
        setState(() {
          _photo = picked;
          _coverPath = null;
        });
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  String? _validate() {
    final name = _nickname.text.trim();
    if (_speciesId == null) {
      return 'Choose a species first.';
    }
    if (name.isEmpty) {
      return 'Give the plant a name.';
    }
    if (name.length > 120) {
      return 'Use a shorter name.';
    }
    if (_location == null) {
      return 'Choose indoors or outdoors.';
    }
    if (_method == null) {
      return 'Choose a pot or the ground.';
    }
    if (_light == null) {
      return 'Choose the light it gets.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_plantSaved) {
        await _create();
        _plantSaved = true;
      }
      await widget.onCreated?.call();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _create() async {
    final speciesId = _speciesId;
    final location = _location;
    final method = _method;
    final light = _light;
    if (speciesId == null ||
        location == null ||
        method == null ||
        light == null) {
      throw const MalformedDataException('Choose a species first.');
    }

    final plantId = _plantId ??= _uuid.v4();
    var coverPath = _coverPath;
    final photo = _photo;
    if (photo != null && coverPath == null) {
      final uploaded = await ref
          .read(photoRepositoryProvider)
          .uploadPhoto(
            plantId: plantId,
            bytes: photo.bytes,
            contentType: photo.contentType,
          );
      coverPath = uploaded.storagePath;
      _coverPath = coverPath;
    }

    await ref
        .read(plantRepositoryProvider)
        .createPlant(
          Plant(
            id: plantId,
            speciesId: speciesId,
            displayName: _nickname.text.trim(),
            locationType: location,
            growingMethod: method,
            container: PlantContainer(
              isContainer: method == GrowingMethod.container,
            ),
            environment: PlantEnvironment(sunExposure: light),
            coverPhotoPath: coverPath,
          ),
        );
  }

  Future<void> _skip() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSkip?.call();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onClose != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : widget.onClose,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.terracotta,
              ),
              child: Text(
                'Close',
                style: AppText.label.copyWith(color: AppColors.terracotta),
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.eyebrow,
                  style: AppText.eyebrow.copyWith(color: AppColors.green),
                ),
                const SizedBox(height: 2.5),
                Text(
                  widget.title,
                  style: AppText.display.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 16),
                if (_phase == _Phase.search) _searchBody() else _detailsBody(),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppText.body.copyWith(color: AppColors.terracottaBright),
          ),
        ],
        if (_phase == _Phase.details) ...[
          const SizedBox(height: 12),
          AuthPrimaryButton(
            label: 'Add plant',
            isLoading: _busy,
            onPressed: _busy ? null : _save,
          ),
        ],
        if (widget.onSkip != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : _skip,
              child: Text(
                "I'll add a plant later",
                style: AppText.titleSemiBold.copyWith(
                  color: AppColors.terracotta,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _searchBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _query,
          enabled: !_busy,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          style: AppText.input.copyWith(color: AppColors.ink),
          cursorColor: AppColors.terracotta,
          decoration: _fieldDecoration('Search by name'),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: 'Search',
          isLoading: _busy && !_resolving,
          onPressed: _busy ? null : _search,
        ),
        if (_resolving) ...[
          const SizedBox(height: 12),
          Text(
            'Looking up care advice…',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        ],
        const SizedBox(height: 16),
        if (_searched && _results.isEmpty)
          Text(
            'No matches. Try a botanical name.',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        for (final candidate in _results) ...[
          _ResultTile(
            candidate: candidate,
            onTap: _busy ? null : () => _choose(candidate),
          ),
          const SizedBox(height: 8),
        ],
        if (_attribution != null && _attribution!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _attribution!,
            style: AppText.body.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _detailsBody() {
    final candidate = _candidate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_plantSaved)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _phase = _Phase.search),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'Choose a different species',
                style: AppText.label.copyWith(color: AppColors.terracotta),
              ),
            ),
          ),
        if (candidate != null) ...[
          Text(
            candidate.displayName,
            style: AppText.plantName.copyWith(color: AppColors.ink),
          ),
          if (candidate.scientificName.isNotEmpty &&
              candidate.scientificName != candidate.displayName)
            Text(
              candidate.scientificName,
              style: AppText.bodyItalic.copyWith(color: AppColors.body),
            ),
          const SizedBox(height: 16),
        ],
        _BlushField(
          label: 'Name',
          controller: _nickname,
          hintText: 'What you call it',
          enabled: !_busy,
        ),
        const SizedBox(height: 16),
        _ChoiceLabel('Where it lives'),
        if (widget.explain) ...[
          const SizedBox(height: 4),
          Text(
            'Indoors stays out of frost. Outdoors follows the zone you saved.',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        ],
        const SizedBox(height: 8),
        _Pair(
          left: 'Indoors',
          right: 'Outdoors',
          leftSelected: _location == LocationType.indoor,
          rightSelected: _location == LocationType.outdoor,
          onLeft: _busy
              ? null
              : () => setState(() => _location = LocationType.indoor),
          onRight: _busy
              ? null
              : () => setState(() => _location = LocationType.outdoor),
        ),
        const SizedBox(height: 16),
        const _ChoiceLabel('Pot or ground'),
        const SizedBox(height: 8),
        _Pair(
          left: 'Pot',
          right: 'In the ground',
          leftSelected: _method == GrowingMethod.container,
          rightSelected: _method == GrowingMethod.inGround,
          onLeft: _busy
              ? null
              : () => setState(() => _method = GrowingMethod.container),
          onRight: _busy
              ? null
              : () => setState(() => _method = GrowingMethod.inGround),
        ),
        const SizedBox(height: 16),
        _ChoiceLabel('Light'),
        if (widget.explain) ...[
          const SizedBox(height: 4),
          Text(
            'Choose the light it actually gets where it sits.',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _lights)
              _LightChip(
                label: option.$2,
                selected: _light == option.$1,
                onTap: _busy ? null : () => setState(() => _light = option.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _ChoiceLabel('Photo'),
        const SizedBox(height: 4),
        Text('Optional.', style: AppText.body.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        _PhotoWell(photo: _photo, onTap: _busy ? null : _pickPhoto),
        if (_sparse) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.amber,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            child: Text(
              'This schedule is a starting default. The species record '
              'did not have enough detail for a custom cadence.',
              style: AppText.body.copyWith(color: AppColors.amberInk),
            ),
          ),
        ],
      ],
    );
  }
}

const _lights = <(SunExposure, String)>[
  (SunExposure.fullSun, 'Full sun'),
  (SunExposure.partialSun, 'Partial sun'),
  (SunExposure.partialShade, 'Partial shade'),
  (SunExposure.fullShade, 'Shade'),
  (SunExposure.brightIndirect, 'Bright indirect'),
  (SunExposure.lowLight, 'Low light'),
];

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: AppColors.surfaceBlush,
  hintText: hint,
  hintStyle: AppText.input.copyWith(color: AppColors.muted),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  border: _border(),
  enabledBorder: _border(),
  disabledBorder: _border(),
  focusedBorder: _border(AppColors.terracotta),
);

InputBorder _border([Color? color]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppSizes.imageRadius),
  borderSide: color == null
      ? BorderSide.none
      : BorderSide(color: color, width: 1.5),
);

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.candidate, required this.onTap});

  final SpeciesCandidate candidate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scientific = candidate.scientificName;
    final showScientific =
        scientific.isNotEmpty && scientific != candidate.displayName;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.displayName,
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
              if (showScientific)
                Text(
                  scientific,
                  style: AppText.bodyItalic.copyWith(color: AppColors.body),
                ),
              if (candidate.family case final family?)
                Text(
                  family,
                  style: AppText.body.copyWith(color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceLabel extends StatelessWidget {
  const _ChoiceLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.fieldLabel.copyWith(color: AppColors.body),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.rightSelected,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final bool rightSelected;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SelectCard(
            label: left,
            selected: leftSelected,
            onTap: onLeft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SelectCard(
            label: right,
            selected: rightSelected,
            onTap: onRight,
          ),
        ),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceWarm : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(
              color: selected ? AppColors.terracotta : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Text(
            label,
            style: AppText.titleSemiBold.copyWith(color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  const _LightChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.terracotta : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: AppText.label.copyWith(
              color: selected ? AppColors.surface : AppColors.body,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlushField extends StatelessWidget {
  const _BlushField({
    required this.label,
    required this.controller,
    this.hintText,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.fieldLabel.copyWith(color: AppColors.body)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.input.copyWith(color: AppColors.ink),
          cursorColor: AppColors.terracotta,
          decoration: _fieldDecoration(hintText ?? ''),
        ),
      ],
    );
  }
}

class _PhotoWell extends StatelessWidget {
  const _PhotoWell({required this.photo, required this.onTap});

  final PickedGardenPhoto? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceBlush,
                shape: BoxShape.circle,
                image: photo == null
                    ? null
                    : DecorationImage(
                        image: MemoryImage(photo!.bytes),
                        fit: BoxFit.cover,
                      ),
              ),
              child: photo == null
                  ? const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.muted,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              photo == null ? 'Add a photo' : 'Change photo',
              style: AppText.label.copyWith(color: AppColors.terracotta),
            ),
          ],
        ),
      ),
    );
  }
}
