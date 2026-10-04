import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import '../../../app/assets.dart';
import '../../../app/shell/flow_header.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../photos/data/photo_repository.dart';
import '../../photos/presentation/photo_picker.dart';
import '../data/plant_repository.dart';
import '../data/recent_searches.dart';
import '../data/species_repository.dart';
import '../domain/garden_spot.dart';
import '../domain/plant.dart';

/// The two steps of adding a plant: choose a species, then set it up.
///
/// Searching writes nothing. Picking a result and pressing continue runs
/// [SpeciesRepository.resolve], which caches the species so `onPlantCreated`
/// finds a care profile to seed reminders from. Shared by onboarding and
/// `/add-plant`.
class AddPlantFlow extends ConsumerStatefulWidget {
  const AddPlantFlow({
    super.key,
    required this.explain,
    this.eyebrow = 'ADD TO YOUR LIVING CATALOG',
    this.title = 'Find your next green companion',
    this.showProgress = true,
    this.onCreated,
    this.onSkip,
    this.onStepChanged,
  });

  /// Beginners get one sentence on each choice.
  final bool explain;
  final String eyebrow;
  final String title;

  /// False where the host already shows its own steps, as onboarding does.
  final bool showProgress;

  /// After the plant document is written, with the new plant's id. Onboarding
  /// finishes the profile here; the add-plant route opens the plant.
  final Future<void> Function(String plantId)? onCreated;

  /// Onboarding only. Leaves without creating a plant.
  final Future<void> Function()? onSkip;

  /// One-based step, so the host can title its header.
  final ValueChanged<int>? onStepChanged;

  @override
  ConsumerState<AddPlantFlow> createState() => AddPlantFlowState();
}

enum _Phase { search, setup }

class AddPlantFlowState extends ConsumerState<AddPlantFlow> {
  static const _uuid = Uuid();

  final _query = TextEditingController();

  var _phase = _Phase.search;
  var _busy = false;
  var _resolving = false;
  var _searched = false;
  String? _error;
  String? _searchedTerm;
  String? _attribution;
  String? _speciesId;
  String? _plantId;
  String? _coverPath;
  List<SpeciesCandidate> _results = const [];
  SpeciesCandidate? _selected;
  PickedGardenPhoto? _photo;
  GardenSpot? _garden;
  PlantAgeStage? _stage;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// True when the flow handled the back gesture itself.
  bool goBack() {
    if (_phase == _Phase.setup && !_busy) {
      _toSearch();
      return true;
    }
    return false;
  }

  void _setPhase(_Phase phase) {
    setState(() => _phase = phase);
    widget.onStepChanged?.call(phase == _Phase.search ? 1 : 2);
  }

  void _toSearch() {
    setState(() => _error = null);
    _setPhase(_Phase.search);
  }

  Future<void> _search([String? term]) async {
    final query = (term ?? _query.text).trim();
    if (term != null) {
      _query.text = term;
    }
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
      ref.read(recentSearchesProvider.notifier).remember(query);
      setState(() {
        _results = result.candidates;
        _attribution = result.attribution;
        _searched = true;
        _searchedTerm = query;
        _selected = null;
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

  void _clearQuery() {
    _query.clear();
    setState(() {
      _results = const [];
      _searched = false;
      _searchedTerm = null;
      _selected = null;
      _error = null;
    });
  }

  /// Caches the chosen species, then moves to setup.
  Future<void> _continueToSetup() async {
    final candidate = _selected;
    if (candidate == null) {
      setState(() => _error = 'Choose a plant to continue.');
      return;
    }

    setState(() {
      _busy = true;
      _resolving = true;
      _error = null;
    });
    try {
      final speciesId = await ref
          .read(speciesRepositoryProvider)
          .resolve(
            speciesId: candidate.speciesId.isEmpty ? null : candidate.speciesId,
            trefleSlug: candidate.trefleSlug,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _speciesId = speciesId;
        _plantId = null;
        _coverPath = null;
      });
      _setPhase(_Phase.setup);
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
    if (_speciesId == null) {
      return 'Choose a plant first.';
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
    final speciesId = _speciesId;
    final garden = _garden;
    final stage = _stage;
    if (speciesId == null || garden == null || stage == null) {
      throw const MalformedDataException('Choose a plant first.');
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
            displayName: _selected?.displayName ?? 'My plant',
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
    return plantId;
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
        if (widget.showProgress) ...[
          FlowProgress(step: _phase == _Phase.search ? 1 : 2, stepCount: 3),
          const SizedBox(height: AppSizes.sectionGap),
        ],
        if (_phase == _Phase.search) _searchBody() else _setupBody(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: AppText.body.copyWith(color: AppColors.terracottaBright),
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

  // ---------------------------------------------------------------- step one

  Widget _searchBody() {
    final recents = ref.watch(recentSearchesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          "Search by the name you know. We'll help with the botanical details.",
          style: AppText.bodyLarge.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: AppSizes.sectionGap),
        _SearchField(
          controller: _query,
          enabled: !_busy,
          onSubmitted: () => _search(),
          onClear: _clearQuery,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SvgPicture.asset(AppIcons.hintSparkles, width: 14, height: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Try "Swiss cheese plant" or "Monstera deliciosa"',
                style: AppText.caption.copyWith(color: AppColors.body),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PrimaryAction(
          label: 'Search',
          icon: AppIcons.searchGlass,
          isLoading: _busy && !_resolving,
          onPressed: _busy ? null : () => _search(),
        ),
        if (recents.isNotEmpty || !_searched) ...[
          const SizedBox(height: AppSizes.sectionGap),
          _SuggestionsSection(
            recents: recents,
            onPick: _busy ? null : (term) => _search(term),
            onClear: recents.isEmpty
                ? null
                : () => ref.read(recentSearchesProvider.notifier).clear(),
          ),
        ],
        if (_resolving) ...[
          const SizedBox(height: AppSizes.sectionGap),
          Text(
            'Looking up care advice…',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        ],
        if (_searched) ...[
          const SizedBox(height: AppSizes.sectionGap),
          _ResultsHeading(term: _searchedTerm ?? '', count: _results.length),
          const SizedBox(height: 12),
          if (_results.isEmpty)
            Text(
              'No matches. Try the everyday name, like tomato or basil.',
              style: AppText.bodyLarge.copyWith(color: AppColors.body),
            ),
          for (final candidate in _results) ...[
            _ResultCard(
              candidate: candidate,
              isSelected: candidate.trefleSlug == _selected?.trefleSlug &&
                  candidate.scientificName == _selected?.scientificName,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _selected = candidate;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (_selected case final selected?) ...[
          const SizedBox(height: 4),
          _SelectionFooter(
            name: selected.displayName,
            isLoading: _busy,
            onContinue: _busy ? null : _continueToSetup,
          ),
        ],
        if (_attribution case final attribution?
            when attribution.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            attribution,
            style: AppText.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- step two

  Widget _setupBody() {
    final selected = _selected;
    final garden = _garden;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected != null)
          _SelectedSummary(
            candidate: selected,
            onChange: _busy ? null : _toSearch,
          ),
        const SizedBox(height: AppSizes.sectionGap),
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
        const _SectionCopy(
          title: 'Add your own picture',
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
          label: selected == null
              ? 'Add to my profile'
              : 'Add ${_firstWord(selected.displayName)} to my profile',
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

/// Starting points for someone with an empty search box. Common houseplants
/// and kitchen-garden staples, so the catalog answers with something.
const _suggestions = <({String label, String icon})>[
  (label: 'Monstera', icon: AppIcons.suggestionSparkles),
  (label: 'Snake plant', icon: AppIcons.suggestionPaw),
  (label: 'Tomato', icon: AppIcons.suggestionSparkles),
  (label: 'Basil', icon: AppIcons.suggestionPaw),
  (label: 'Aloe', icon: AppIcons.suggestionSparkles),
];

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

/// Stage labels, for the same reason.
String plantStageLabel(PlantAgeStage stage) =>
    _stageCopy[stage]?.label ?? 'Unknown';

// --------------------------------------------------------------- step one bits

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlush,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.terracotta),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          SvgPicture.asset(AppIcons.searchGlass, width: 18, height: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmitted(),
              style: AppText.input.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: AppColors.terracotta,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search by common name',
                hintStyle: AppText.input.copyWith(color: AppColors.muted),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return Semantics(
                button: true,
                label: 'Clear search',
                child: GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      AppIcons.searchClear,
                      width: 14,
                      height: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuggestionsSection extends StatelessWidget {
  const _SuggestionsSection({
    required this.recents,
    required this.onPick,
    required this.onClear,
  });

  final List<String> recents;
  final ValueChanged<String>? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(AppIcons.recentClock, width: 18, height: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recent & suggested',
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Text(
                  'Clear',
                  style: AppText.label.copyWith(color: AppColors.terracotta),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in recents)
              _ChoicePill(
                label: term,
                icon: AppIcons.recentHistory,
                onTap: onPick == null ? null : () => onPick!(term),
              ),
            for (final suggestion in _suggestions)
              _ChoicePill(
                label: suggestion.label,
                icon: suggestion.icon,
                onTap: onPick == null ? null : () => onPick!(suggestion.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.icon, this.onTap});

  final String label;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceBlush,
      borderRadius: BorderRadius.circular(AppSizes.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(icon, width: 14, height: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.fieldLabel.copyWith(color: AppColors.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsHeading extends StatelessWidget {
  const _ResultsHeading({required this.term, required this.count});

  final String term;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Plants matching "$term"',
            style: AppText.title.copyWith(color: AppColors.ink),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          count == 1 ? '1 found' : '$count found',
          style: AppText.label.copyWith(color: AppColors.green),
        ),
      ],
    );
  }
}

/// One candidate. The catalog search carries a name, a botanical name, a
/// family and sometimes a photo; the description and care tags in the design
/// only exist once a species has been resolved, so they are not shown here.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.candidate,
    required this.isSelected,
    required this.onTap,
  });

  final SpeciesCandidate candidate;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scientific = candidate.scientificName;
    final showScientific =
        scientific.isNotEmpty && scientific != candidate.displayName;

    return Material(
      color: isSelected ? AppColors.surfaceWarm : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
            border: Border.all(
              color: isSelected ? AppColors.terracotta : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              _ResultPhoto(url: candidate.imageUrl, isSelected: isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            candidate.displayName,
                            style: AppText.plantTitle.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        SvgPicture.asset(
                          isSelected
                              ? AppIcons.resultChevronSelected
                              : AppIcons.resultChevron,
                          width: 17,
                          height: 17,
                        ),
                      ],
                    ),
                    if (showScientific) ...[
                      const SizedBox(height: 6),
                      Text(
                        scientific,
                        style: AppText.bodyItalic.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    ],
                    if (candidate.family case final family?
                        when family.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _Tag(label: family),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPhoto extends StatelessWidget {
  const _ResultPhoto({required this.url, required this.isSelected});

  final String? url;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final address = url;
    return SizedBox(
      width: 94,
      height: 112,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              child: address == null || address.isEmpty
                  ? const _PhotoPlaceholder()
                  : Image.network(
                      address,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _PhotoPlaceholder(),
                    ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 7,
              left: 7,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  AppIcons.resultSelectedCheck,
                  width: 12,
                  height: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Trefle often has no photo for a species, so the slot has to stand alone.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceBlush,
      child: Center(
        child: SvgPicture.asset(AppIcons.growingSprout, width: 24, height: 24),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppSizes.pill),
      ),
      child: Text(
        label,
        style: AppText.label.copyWith(color: AppColors.green),
      ),
    );
  }
}

class _SelectionFooter extends StatelessWidget {
  const _SelectionFooter({
    required this.name,
    required this.isLoading,
    required this.onContinue,
  });

  final String name;
  final bool isLoading;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECTED',
                      style: AppText.eyebrow.copyWith(color: AppColors.green),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: AppText.cardTitle.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  AppIcons.selectionCheck,
                  width: 16,
                  height: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PrimaryAction(
            label: 'Continue to plant setup',
            icon: AppIcons.ctaArrowRight,
            isLoading: isLoading,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- step two bits

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({required this.candidate, required this.onChange});

  final SpeciesCandidate candidate;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final scientific = candidate.scientificName;
    final showScientific =
        scientific.isNotEmpty && scientific != candidate.displayName;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              child: candidate.imageUrl == null || candidate.imageUrl!.isEmpty
                  ? const _PhotoPlaceholder()
                  : Image.network(
                      candidate.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _PhotoPlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR NEW PLANT',
                  style: AppText.eyebrow.copyWith(color: AppColors.green),
                ),
                const SizedBox(height: 3),
                Text(
                  candidate.displayName,
                  style: AppText.plantTitle.copyWith(color: AppColors.ink),
                ),
                if (showScientific) ...[
                  const SizedBox(height: 3),
                  Text(
                    scientific,
                    style: AppText.bodyItalic.copyWith(color: AppColors.body),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Choose a different plant',
            child: GestureDetector(
              onTap: onChange,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  AppIcons.setupChangePencil,
                  width: 15,
                  height: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
          Text(
            text,
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
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
                      borderRadius: BorderRadius.circular(
                        AppSizes.cardRadius,
                      ),
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
      child: DottedBorderBox(
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
                    'JPG or PNG · the catalog photo stays as a backup',
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
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

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
