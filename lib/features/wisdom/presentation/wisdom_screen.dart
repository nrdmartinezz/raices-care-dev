import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/assets.dart';
import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../planting/data/planting_repository.dart';
import '../../planting/presentation/frost_calendar_card.dart';
import '../../plants/data/recent_searches.dart';
import '../../plants/data/species_repository.dart';

/// Tab 4 — search the shared species catalog.
class WisdomScreen extends ConsumerStatefulWidget {
  const WisdomScreen({super.key});

  @override
  ConsumerState<WisdomScreen> createState() => _WisdomScreenState();
}

class _WisdomScreenState extends ConsumerState<WisdomScreen> {
  final _query = TextEditingController();
  var _busy = false;
  var _searched = false;
  String? _error;
  String? _term;
  String? _attribution;
  List<SpeciesCandidate> _results = const [];
  Map<String, bool?> _seasons = const {};

  static const _suggestions = [
    'Monstera',
    'Snake plant',
    'Tomato',
    'Basil',
    'Aloe',
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
        _term = query;
        _seasons = const {};
      });
      final seasons = await _seasonsFor(result.candidates);
      if (!mounted) return;
      setState(() => _seasons = seasons);
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

  Future<Map<String, bool?>> _seasonsFor(List<SpeciesCandidate> results) async {
    final garden = ref.read(gardenFrostProvider).value;
    final repository = ref.read(plantingRepositoryProvider);
    if (garden is! GardenFrostReady || repository == null) return const {};
    final names = [
      for (final candidate in results)
        if (candidate.scientificName.trim().isNotEmpty)
          candidate.scientificName,
    ];
    if (names.isEmpty) return const {};
    try {
      return await repository.seasons(
        latitude: garden.latitude,
        longitude: garden.longitude,
        names: names,
      );
    } on AppException {
      return const {};
    }
  }

  void _open(SpeciesCandidate candidate) {
    final slug = candidate.trefleSlug;
    final id = candidate.speciesId.isNotEmpty ? candidate.speciesId : slug;
    if (id == null || id.isEmpty) {
      setState(() => _error = 'That plant has no catalog id.');
      return;
    }
    context.pushNamed(
      SpeciesArticleRoute.name,
      pathParameters: {'speciesId': id},
      queryParameters: {if (slug != null && slug.isNotEmpty) 'slug': slug},
    );
  }

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentSearchesProvider);
    ref.listen(gardenFrostProvider, (previous, next) {
      final garden = next.value;
      if (garden is! GardenFrostReady || !_searched || _results.isEmpty) {
        return;
      }
      if (_seasons.isNotEmpty) return;
      _seasonsFor(_results).then((seasons) {
        if (mounted) setState(() => _seasons = seasons);
      });
    });

    return ShellScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROWING LORE',
            style: AppText.eyebrow.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 7),
          Text('Wisdom', style: AppText.display.copyWith(color: AppColors.ink)),
          const SizedBox(height: 7),
          Text(
            'Look up a plant before you bring it home.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          ref
              .watch(gardenFrostProvider)
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) =>
                    const FrostCalendarCard(frost: GardenFrostUnavailable()),
                data: (frost) => FrostCalendarCard(frost: frost),
              ),
          const SizedBox(height: AppSizes.sectionGap),
          _SearchField(
            controller: _query,
            enabled: !_busy,
            onSubmitted: _search,
          ),
          const SizedBox(height: 12),
          _SearchButton(isLoading: _busy, onPressed: _busy ? null : _search),
          if (recents.isNotEmpty || !_searched) ...[
            const SizedBox(height: AppSizes.sectionGap),
            Text(
              'Recent & suggested',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in recents)
                  _Pill(label: term, onTap: _busy ? null : () => _search(term)),
                for (final suggestion in _suggestions)
                  _Pill(
                    label: suggestion,
                    onTap: _busy ? null : () => _search(suggestion),
                  ),
              ],
            ),
          ],
          if (_error case final message?) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: AppText.body.copyWith(color: AppColors.terracottaBright),
            ),
          ],
          if (_searched) ...[
            const SizedBox(height: AppSizes.sectionGap),
            Text(
              _results.isEmpty
                  ? 'No matches for "${_term ?? ''}"'
                  : 'Plants matching "${_term ?? ''}"',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            if (_results.isEmpty)
              Text(
                'Try the everyday name, like tomato or basil.',
                style: AppText.bodyLarge.copyWith(color: AppColors.body),
              ),
            for (final candidate in _results) ...[
              _ResultCard(
                candidate: candidate,
                inSeason: _seasons[candidate.scientificName.toLowerCase()],
                onTap: () => _open(candidate),
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (_attribution case final attribution? when attribution.isNotEmpty)
            Text(
              attribution,
              style: AppText.caption.copyWith(color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlush,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.terracotta),
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
                hintText: 'Search by common name',
                hintStyle: AppText.input.copyWith(color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.surface,
                ),
              )
            : Text(
                'Search',
                style: AppText.title.copyWith(color: AppColors.surface),
              ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.onTap});

  final String label;
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
          child: Text(
            label,
            style: AppText.fieldLabel.copyWith(color: AppColors.body),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.candidate,
    required this.onTap,
    required this.inSeason,
  });

  final SpeciesCandidate candidate;
  final VoidCallback onTap;
  final bool? inSeason;

  @override
  Widget build(BuildContext context) {
    final scientific = candidate.scientificName;
    final showScientific =
        scientific.isNotEmpty && scientific != candidate.displayName;
    final radius = BorderRadius.circular(AppSizes.cardRadius + 4);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: candidate.imageUrl == null
                      ? const ColoredBox(color: AppColors.surfaceBlush)
                      : Image.network(
                          candidate.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(color: AppColors.surfaceBlush),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.displayName,
                      style: AppText.plantTitle.copyWith(color: AppColors.ink),
                    ),
                    if (inSeason != null) ...[
                      const SizedBox(height: 6),
                      SeasonPill(inSeason: inSeason!),
                    ],
                    if (showScientific) ...[
                      const SizedBox(height: 4),
                      Text(
                        scientific,
                        style: AppText.bodyItalic.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    ],
                    if (candidate.family case final family?
                        when family.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        family,
                        style: AppText.label.copyWith(color: AppColors.green),
                      ),
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
