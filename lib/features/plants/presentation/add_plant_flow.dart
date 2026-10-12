import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import '../../../app/assets.dart';
import '../../../app/shell/flow_header.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../settings/data/user_settings_repository.dart';
import '../../photos/data/photo_repository.dart';
import '../../photos/presentation/photo_picker.dart';
import '../data/plant_repository.dart';
import '../data/species_repository.dart';
import '../domain/garden_spot.dart';
import '../domain/plant.dart';

/// The two steps of adding a plant: name it, then say where and how old it is.
///
/// Care is looked up after the plant exists and stored on that plant.
/// Shared by onboarding and `/add-plant`.
class AddPlantFlow extends ConsumerStatefulWidget {
  const AddPlantFlow({
    super.key,
    required this.explain,
    this.eyebrow = 'ADD A PLANT',
    this.title = 'Name your plant',
    this.showProgress = true,
    this.preset,
    this.onCreated,
    this.onSkip,
    this.onStepChanged,
    this.onCanPop,
  });

  /// Beginners get one sentence on each choice.
  final bool explain;
  final String eyebrow;
  final String title;

  /// False where the host already shows its own steps, as onboarding does.
  final bool showProgress;

  /// A species already chosen, such as from a Wisdom article. Setup opens
  /// immediately with that plant's name filled in.
  final SpeciesCandidate? preset;

  /// After the plant document is written, with the new plant's id. Onboarding
  /// finishes the profile here; the add-plant route opens the plant.
  final Future<void> Function(String plantId)? onCreated;

  /// Onboarding only. Leaves without creating a plant.
  final Future<void> Function()? onSkip;

  /// One-based step, so the host can title its header.
  final ValueChanged<int>? onStepChanged;

  /// False while filters are open, so the host keeps the system back gesture
  /// inside the flow.
  final ValueChanged<bool>? onCanPop;

  @override
  ConsumerState<AddPlantFlow> createState() => AddPlantFlowState();
}

enum _Phase { name, setup }

class AddPlantFlowState extends ConsumerState<AddPlantFlow> {
  static const _uuid = Uuid();

  final _name = TextEditingController();

  var _phase = _Phase.name;
  var _busy = false;
  String? _error;
  String? _speciesId;
  String? _plantId;
  String? _coverPath;
  PickedGardenPhoto? _photo;
  GardenSpot? _garden;
  PlantAgeStage? _stage;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    if (preset == null) return;
    _name.text = preset.displayName;
    if (preset.speciesId.isNotEmpty) _speciesId = preset.speciesId;
    _phase = _Phase.setup;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// True when the flow handled the back gesture itself.
  bool goBack() {
    if (widget.preset != null) return false;
    if (_phase == _Phase.setup && !_busy) {
      setState(() => _error = null);
      _setPhase(_Phase.name);
      return true;
    }
    return false;
  }

  void _setPhase(_Phase phase) {
    setState(() => _phase = phase);
    widget.onStepChanged?.call(phase == _Phase.setup ? 2 : 1);
    widget.onCanPop?.call(widget.preset != null || phase == _Phase.name);
  }

  void _continueToSetup() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (name.length > 120) {
      setState(() => _error = 'Use a shorter name.');
      return;
    }
    setState(() => _error = null);
    _setPhase(_Phase.setup);
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await pickGardenPhoto(context, crop: PhotoCrop.landscape);
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
    if (_name.text.trim().isEmpty) {
      return 'Enter a name.';
    }
    if (_garden == null) {
      return 'Choose where it will grow.';
    }
    if (_stage == null) {
      return 'Choose how old it is.';
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
      final plantId = await _create();
      await widget.onCreated?.call(plantId);
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

  Future<String> _create() async {
    final garden = _garden;
    final stage = _stage;
    final name = _name.text.trim();
    if (name.isEmpty || garden == null || stage == null) {
      throw const MalformedDataException('Enter a name first.');
    }

    final existing = ref.read(activePlantsProvider).asData?.value;
    final firstPlant = existing == null || existing.isEmpty;
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
            speciesId: _speciesId ?? '',
            displayName: name,
            gardenId: garden.wire,
            locationType: garden.locationType,
            growingMethod: garden.growingMethod,
            plantAgeStage: stage,
            container: PlantContainer(
              isContainer: garden.growingMethod == GrowingMethod.container,
            ),
            // The flow does not ask after the plant's condition, and a plant
            // someone just chose to keep is a healthy one until they say
            // otherwise.
            status: const PlantStatus(health: PlantHealth.healthy),
            coverPhotoPath: coverPath,
          ),
        );
    if (firstPlant) {
      await _offerCareNotifications();
    }
    return plantId;
  }

  /// The plant is already saved if this fails. Web never prompts.
  Future<void> _offerCareNotifications() async {
    if (kIsWeb) {
      return;
    }
    try {
      await ref.read(userSettingsRepositoryProvider).enablePushNotifications();
    } on AppException {
      // Permission can be granted on a later launch.
    }
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _phase == _Phase.name ? _nameScroll() : _setupScroll(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppText.body.copyWith(color: AppColors.terracottaBright),
          ),
        ],
        if (widget.onSkip != null)
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
    );
  }

  // ---------------------------------------------------------------- step one

  Widget _setupScroll() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showProgress) ...[
            const FlowProgress(step: 2, stepCount: 3),
            const SizedBox(height: AppSizes.sectionGap),
          ],
          _setupBody(),
        ],
      ),
    );
  }

  Widget _nameScroll() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showProgress) ...[
            const FlowProgress(step: 1, stepCount: 3),
            const SizedBox(height: AppSizes.sectionGap),
          ],
          Text(
            widget.eyebrow,
            style: AppText.eyebrow.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 7),
          Text(
            widget.title,
            style: AppText.display.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 7),
          Text(
            "Use the name you know. Care advice is added after the plant is saved.",
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          TextField(
            controller: _name,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _continueToSetup(),
            style: AppText.input.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: AppColors.terracotta,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Bell pepper',
              hintStyle: AppText.input.copyWith(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          const _SectionCopy(
            title: 'Add a picture',
            optional: true,
            description: 'A first photo makes growth changes easier to notice.',
          ),
          const SizedBox(height: 12),
          _PhotoWell(photo: _photo, onTap: _busy ? null : _pickPhoto),
          const SizedBox(height: 12),
          Row(
            children: [
              SvgPicture.asset(AppIcons.setupCircleCheck, width: 14, height: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'You can add or update this later',
                  style: AppText.caption.copyWith(color: AppColors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _PrimaryAction(
            label: 'Continue',
            icon: AppIcons.ctaArrowRight,
            isLoading: false,
            onPressed: _busy ? null : _continueToSetup,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- step two

  Widget _setupBody() {
    final garden = _garden;
    final name = _name.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCopy(
          title: 'Where will it grow?',
          trailing: 'Required',
          description: widget.explain
              ? 'Choose a garden so care reminders match its conditions.'
              : null,
        ),
        const SizedBox(height: 12),
        _GardenGrid(
          selected: garden,
          onSelect: _busy
              ? null
              : (spot) => setState(() {
                  _garden = spot;
                  _error = null;
                }),
        ),
        const SizedBox(height: AppSizes.sectionGap),
        const _SectionCopy(
          title: 'How old is your plant?',
          trailing: 'Required',
          description: 'An estimate is perfectly fine.',
        ),
        const SizedBox(height: 12),
        _StageGrid(
          selected: _stage,
          onSelect: _busy
              ? null
              : (stage) => setState(() {
                  _stage = stage;
                  _error = null;
                }),
        ),
        const SizedBox(height: AppSizes.sectionGap),
        _PrimaryAction(
          label: name.isEmpty
              ? 'Add to my profile'
              : 'Add ${_firstWord(name)} to my profile',
          icon: AppIcons.ctaSprout,
          isLoading: _busy,
          onPressed: _busy ? null : _save,
        ),
        if (garden != null) ...[
          const SizedBox(height: 10),
          Text(
            "Next, we'll build a care rhythm for your "
            '${_gardenCopy[garden]!.label} garden.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.body),
          ),
        ],
      ],
    );
  }
}

String _firstWord(String value) {
  final trimmed = value.trim();
  final space = trimmed.indexOf(' ');
  return space == -1 ? trimmed : trimmed.substring(0, space);
}

/// Label, second line and glyph for each garden. Kept out of [GardenSpot] so
/// the domain does not reach for assets.
const _gardenCopy = <GardenSpot, ({String label, String hint, String icon})>{
  GardenSpot.indoor: (
    label: 'Indoor',
    hint: 'A room, on a sill or a shelf',
    icon: AppIcons.gardenIndoor,
  ),
  GardenSpot.backyard: (
    label: 'Backyard',
    hint: 'Open air, afternoon sun',
    icon: AppIcons.gardenBackyard,
  ),
  GardenSpot.frontyard: (
    label: 'Frontyard',
    hint: 'Porch, morning light',
    icon: AppIcons.gardenFrontyard,
  ),
  GardenSpot.balcony: (
    label: 'Balcony',
    hint: 'High light, breezy',
    icon: AppIcons.gardenBalcony,
  ),
};

const _stageCopy = <PlantAgeStage, ({String label, String hint})>{
  PlantAgeStage.seed: (label: 'Seed', hint: 'Not up yet'),
  PlantAgeStage.seedling: (label: 'Seedling', hint: 'First few leaves'),
  PlantAgeStage.youngEstablishing: (
    label: 'Young',
    hint: 'Growing, still settling in',
  ),
  PlantAgeStage.mature: (label: 'Mature', hint: 'Full size, well rooted'),
};

/// Garden labels for anything outside the flow that shows a plant's spot.
String gardenSpotLabel(GardenSpot spot) => _gardenCopy[spot]!.label;

/// The second line under a garden, such as "A room, on a sill or a shelf".
String gardenSpotHint(GardenSpot spot) => _gardenCopy[spot]!.hint;

/// Stage labels, for the same reason.
String plantStageLabel(PlantAgeStage stage) =>
    _stageCopy[stage]?.label ?? 'Unknown';

// --------------------------------------------------------------- step one bits
class _SectionCopy extends StatelessWidget {
  const _SectionCopy({
    required this.title,
    this.trailing,
    this.optional = false,
    this.description,
  });

  final String title;
  final String? trailing;
  final bool optional;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
            ),
            if (optional)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlush,
                  borderRadius: BorderRadius.circular(AppSizes.pill),
                ),
                child: Text(
                  'Optional',
                  style: AppText.label.copyWith(color: AppColors.body),
                ),
              )
            else if (trailing case final value?)
              Text(
                value,
                style: AppText.label.copyWith(color: AppColors.terracotta),
              ),
          ],
        ),
        if (description case final text?) ...[
          const SizedBox(height: 4),
          Text(text, style: AppText.bodyLarge.copyWith(color: AppColors.body)),
        ],
      ],
    );
  }
}

class _GardenGrid extends StatelessWidget {
  const _GardenGrid({required this.selected, required this.onSelect});

  final GardenSpot? selected;
  final ValueChanged<GardenSpot>? onSelect;

  @override
  Widget build(BuildContext context) {
    const spots = GardenSpot.values;
    return Column(
      children: [
        for (var row = 0; row < spots.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 10),
          // Intrinsic height so both cards in a row match the taller one.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = row; column < row + 2; column++) ...[
                  if (column > row) const SizedBox(width: 10),
                  Expanded(
                    child: _GardenCard(
                      spot: spots[column],
                      isSelected: selected == spots[column],
                      onTap: onSelect == null
                          ? null
                          : () => onSelect!(spots[column]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GardenCard extends StatelessWidget {
  const _GardenCard({
    required this.spot,
    required this.isSelected,
    required this.onTap,
  });

  final GardenSpot spot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final copy = _gardenCopy[spot]!;

    return Material(
      color: isSelected ? AppColors.mintSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
            border: Border.all(
              color: isSelected ? AppColors.green : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.green
                          : AppColors.surfaceBlush,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    ),
                    // One glyph per garden, tinted for the state it is in.
                    child: SvgPicture.asset(
                      copy.icon,
                      width: 17,
                      height: 17,
                      colorFilter: ColorFilter.mode(
                        isSelected ? AppColors.surface : AppColors.terracotta,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _SelectionDot(isSelected: isSelected),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                copy.label,
                style: AppText.subtitleBold.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                copy.hint,
                style: AppText.caption.copyWith(color: AppColors.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageGrid extends StatelessWidget {
  const _StageGrid({required this.selected, required this.onSelect});

  final PlantAgeStage? selected;
  final ValueChanged<PlantAgeStage>? onSelect;

  @override
  Widget build(BuildContext context) {
    final stages = _stageCopy.keys.toList(growable: false);
    return Column(
      children: [
        for (var row = 0; row < stages.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = row; column < row + 2; column++) ...[
                  if (column > row) const SizedBox(width: 10),
                  Expanded(
                    child: _StageCard(
                      stage: stages[column],
                      isSelected: selected == stages[column],
                      onTap: onSelect == null
                          ? null
                          : () => onSelect!(stages[column]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.isSelected,
    required this.onTap,
  });

  final PlantAgeStage stage;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final copy = _stageCopy[stage]!;

    return Material(
      color: isSelected ? AppColors.mintSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
            border: Border.all(
              color: isSelected ? AppColors.green : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.label,
                      style: AppText.subtitleBold.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _SelectionDot(isSelected: isSelected),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                copy.hint,
                style: AppText.caption.copyWith(color: AppColors.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.green : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.green : AppColors.border,
        ),
      ),
      child: isSelected
          ? SvgPicture.asset(
              AppIcons.gardenSelectedCheck,
              width: 11,
              height: 11,
            )
          : null,
    );
  }
}

class _PhotoWell extends StatelessWidget {
  const _PhotoWell({required this.photo, required this.onTap});

  final PickedGardenPhoto? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final picked = photo;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _DottedBorderBox(
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceBlush,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                image: picked == null
                    ? null
                    : DecorationImage(
                        image: MemoryImage(picked.bytes),
                        fit: BoxFit.cover,
                      ),
              ),
              child: picked == null
                  ? SvgPicture.asset(
                      AppIcons.setupCamera,
                      width: 22,
                      height: 22,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    picked == null
                        ? 'Take or choose a photo'
                        : 'Change this photo',
                    style: AppText.subtitleBold.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'JPG or PNG',
                    style: AppText.caption.copyWith(color: AppColors.body),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SvgPicture.asset(AppIcons.resultChevron, width: 17, height: 17),
          ],
        ),
      ),
    );
  }
}

/// The dashed well around the photo picker.
class _DottedBorderBox extends StatelessWidget {
  const _DottedBorderBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  static const _radius = AppSizes.cardRadius + 4;
  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_radius),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final String icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: onPressed == null && !isLoading ? 0.6 : 1,
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.terracotta,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              boxShadow: AppShadows.card,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.surface),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(icon, width: 18, height: 18),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: AppText.title.copyWith(color: AppColors.surface),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
