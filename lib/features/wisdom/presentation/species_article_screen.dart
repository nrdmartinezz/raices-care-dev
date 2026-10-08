import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../planting/data/planting_repository.dart';
import '../../planting/domain/sowing_calendar.dart';
import '../../planting/presentation/sowing_calendar_section.dart';
import '../../plants/data/species_repository.dart';
import '../../plants/domain/care_profile.dart';
import '../../plants/domain/species.dart';
import '../../plants/presentation/care_labels.dart';

/// A catalog species: names, growth facts, care tasks, and the licence credit.
class SpeciesArticleScreen extends ConsumerStatefulWidget {
  const SpeciesArticleScreen({
    super.key,
    required this.speciesId,
    this.trefleSlug,
  });

  final String speciesId;
  final String? trefleSlug;

  @override
  ConsumerState<SpeciesArticleScreen> createState() =>
      _SpeciesArticleScreenState();
}

class _SpeciesArticleScreenState extends ConsumerState<SpeciesArticleScreen> {
  String? _resolvedId;
  String? _error;
  var _resolving = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_resolve);
  }

  Future<void> _resolve() async {
    try {
      final id = await ref
          .read(speciesRepositoryProvider)
          .resolve(speciesId: widget.speciesId, trefleSlug: widget.trefleSlug);
      if (mounted) {
        setState(() {
          _resolvedId = id;
          _resolving = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AppException
              ? error.message
              : 'The catalog could not be opened.';
          _resolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _resolvedId;
    if (_resolving || id == null) {
      return ShellScrollView(
        child: _resolving
            ? const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            : _Message(
                title: 'This plant could not be opened',
                body: _error ?? 'The catalog did not return a species.',
              ),
      );
    }

    final speciesAsync = ref.watch(speciesProvider(id));
    final calendar = ref.watch(sowingForSpeciesProvider(id)).value;
    final profiles = ref.watch(careProfilesProvider(id)).value;
    final sources = ref.watch(speciesSourcesProvider(id)).value;
    final unit =
        ref.watch(userProfileProvider).value?.units.temperature ??
        TemperatureUnit.fahrenheit;

    return ShellScrollView(
      child: speciesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _Message(
          title: 'This plant could not be opened',
          body: error is AppException
              ? error.message
              : 'Something went wrong reading the catalog.',
        ),
        data: (species) {
          if (species == null) {
            return const _Message(
              title: 'Plant not found',
              body: 'The catalog does not have this species yet.',
            );
          }
          return _Article(
            species: species,
            profiles: profiles ?? const [],
            sources: sources ?? const [],
            unit: unit,
            calendar: calendar,
          );
        },
      ),
    );
  }
}

class _Article extends StatelessWidget {
  const _Article({
    required this.species,
    required this.profiles,
    required this.sources,
    required this.unit,
    required this.calendar,
  });

  final Species species;
  final List<CareProfile> profiles;
  final List<SpeciesSource> sources;
  final TemperatureUnit unit;
  final SowingCalendar? calendar;

  @override
  Widget build(BuildContext context) {
    final scientific = species.scientificName;
    final showScientific =
        scientific.isNotEmpty && scientific != species.displayName;
    final facts = _facts(species.growth, unit);
    final tasks = [for (final profile in profiles) ...profile.tasks];
    final credit = _credit(species, sources);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (species.imageUrl case final url? when url.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: AppColors.surfaceBlush),
              ),
            ),
          ),
        const SizedBox(height: AppSizes.sectionGap),
        Text(
          species.displayName,
          style: AppText.display.copyWith(color: AppColors.ink),
        ),
        if (showScientific) ...[
          const SizedBox(height: 4),
          Text(
            scientific,
            style: AppText.bodyItalic.copyWith(color: AppColors.body),
          ),
        ],
        if (species.growth.description case final description?
            when description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description,
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
        ],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: AppSizes.sectionGap),
          Text('Growing', style: AppText.title.copyWith(color: AppColors.ink)),
          const SizedBox(height: 10),
          for (final fact in facts) ...[
            Text(
              fact.label,
              style: AppText.label.copyWith(color: AppColors.green),
            ),
            const SizedBox(height: 2),
            Text(
              fact.value,
              style: AppText.body.copyWith(color: AppColors.body),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: AppSizes.sectionGap),
        Text('Care', style: AppText.title.copyWith(color: AppColors.ink)),
        if (calendar != null && calendar!.hasWindows) ...[
          const SizedBox(height: 12),
          SowingCalendarSection(calendar: calendar!),
        ],
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Text(
            'No care rhythm is published for this plant yet.',
            style: AppText.body.copyWith(color: AppColors.body),
          )
        else
          for (final task in tasks) ...[
            _TaskCard(task: task),
            const SizedBox(height: 10),
          ],
        if (credit.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(credit, style: AppText.caption.copyWith(color: AppColors.muted)),
        ],
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final CareProfileTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: AppText.title.copyWith(color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(
            'Every ${task.intervalDays} days',
            style: AppText.label.copyWith(color: AppColors.green),
          ),
          if (task.instructions case final instructions?
              when instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              instructions,
              style: AppText.body.copyWith(color: AppColors.body),
            ),
          ],
          if (task.isDefaultCadence) ...[
            const SizedBox(height: 6),
            Text(
              'Default cadence. The catalog record was too sparse for a species-specific interval.',
              style: AppText.caption.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.title.copyWith(color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(body, style: AppText.body.copyWith(color: AppColors.body)),
      ],
    );
  }
}

List<({String label, String value})> _facts(
  SpeciesGrowth growth,
  TemperatureUnit unit,
) {
  final facts = <({String label, String value})>[];
  if (growth.light != null) {
    facts.add((label: 'Light', value: lightLabel(growth.light)));
  }
  if (growth.atmosphericHumidity != null) {
    facts.add((label: 'Humidity', value: '${growth.atmosphericHumidity} / 10'));
  }
  if (growth.soilMoisture != null) {
    facts.add((label: 'Soil moisture', value: '${growth.soilMoisture} / 10'));
  }
  final temperature = _temperature(growth, unit);
  if (temperature != null) {
    facts.add((label: 'Temperature', value: temperature));
  }
  if (growth.phMinimum != null || growth.phMaximum != null) {
    facts.add((
      label: 'Soil pH',
      value: _range(growth.phMinimum, growth.phMaximum),
    ));
  }
  if (growth.daysToHarvest != null) {
    facts.add((label: 'Days to harvest', value: '${growth.daysToHarvest}'));
  }
  return facts;
}

String? _temperature(SpeciesGrowth growth, TemperatureUnit unit) {
  final low = growth.minimumTemperatureC;
  final high = growth.maximumTemperatureC;
  if (low == null && high == null) {
    return null;
  }
  String mark(double celsius) {
    final degrees = switch (unit) {
      TemperatureUnit.celsius => celsius,
      TemperatureUnit.fahrenheit => celsius * 9 / 5 + 32,
    };
    return '${degrees.round()}°${unit.wire}';
  }

  if (low != null && high != null) {
    return '${mark(low)} to ${mark(high)}';
  }
  return mark(low ?? high!);
}

String _range(double? low, double? high) {
  if (low != null && high != null) {
    return '$low to $high';
  }
  return '${low ?? high}';
}

String _credit(Species species, List<SpeciesSource> sources) {
  final lines = <String>[
    if (species.attribution?.text case final text? when text.isNotEmpty) text,
    for (final source in sources)
      if (source.attributionText case final text?
          when text.isNotEmpty && text != species.attribution?.text)
        text,
  ];
  return lines.join('\n');
}
