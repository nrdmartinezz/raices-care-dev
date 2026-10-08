import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/assets.dart';
import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../home/data/home_mappers.dart';
import '../../home/data/home_providers.dart';
import '../../home/presentation/widgets/section_state.dart';
import '../../plants/data/plant_repository.dart';
import '../../plants/domain/garden_spot.dart';
import '../../plants/domain/plant.dart';
import '../../plants/presentation/add_plant_flow.dart';
import '../../plants/presentation/care_labels.dart';
import '../data/care_event_repository.dart';
import '../data/chore_completion.dart';
import '../data/garden_schedule.dart';
import '../data/reminder_repository.dart';
import '../domain/care_task_type.dart';
import '../domain/reminder.dart';

/// Which slice of the open schedule the chore list is showing.
enum _ChoreLens { today, all, tomorrow, weekend }

/// Tab 3 — the garden's care rhythm, drawn from open reminders.
class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  final _busy = <String>{};
  String? _error;
  _ChoreLens _lens = _ChoreLens.today;
  DateTime? _day;

  Future<void> _record(GardenChore chore) async {
    final id = chore.reminder.id;
    if (!_busy.add(id)) {
      return;
    }
    setState(() => _error = null);
    try {
      await recordChore(
        events: ref.read(careEventRepositoryProvider),
        reminders: ref.read(reminderRepositoryProvider),
        plantId: chore.plant.id,
        reminderId: id,
        taskType: chore.reminder.taskType,
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(id));
      }
    }
  }

  Future<void> _addCustom(List<Plant> plants) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CustomChoreSheet(plants: plants),
    );
    if (created != true || !mounted) {
      return;
    }
    setState(() {
      _lens = _ChoreLens.today;
      _day = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(gardenScheduleProvider);
    final now = ref.watch(nowProvider);
    final plants = ref.watch(activePlantsProvider).value ?? const <Plant>[];

    return ShellScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Intro(),
          const SizedBox(height: AppSizes.sectionGap),
          switch (schedule) {
            AsyncError(:final error) => SectionMessage(
              title: 'Chores could not load',
              body: describeSectionError(error),
            ),
            AsyncLoading() => const SectionSkeleton(rows: 3),
            AsyncValue(:final value?) => _Hub(
              schedule: value,
              plants: plants,
              now: now,
              lens: _lens,
              day: _day,
              busy: _busy,
              error: _error,
              onLens: (lens) => setState(() {
                _lens = lens;
                _day = null;
              }),
              onDay: (day) => setState(() {
                _lens = _ChoreLens.today;
                _day = day;
              }),
              onRecord: _record,
              onOpen: (plantId) => context.goNamed(
                PlantDetailRoute.name,
                pathParameters: {'plantId': plantId},
              ),
              onAdd: () => _addCustom(plants),
            ),
          },
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(AppIcons.choresEyebrow, width: 15, height: 15),
            const SizedBox(width: 6),
            Text(
              'GARDEN RHYTHM & CARE',
              style: AppText.eyebrow.copyWith(color: AppColors.amberText),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Garden Chores',
          style: AppText.display.copyWith(
            color: AppColors.ink,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ancestral timing, seasonal rituals, and everyday plant care.',
          style: AppText.bodyLarge.copyWith(
            color: AppColors.body,
            height: 22.75 / 14,
          ),
        ),
      ],
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({
    required this.schedule,
    required this.plants,
    required this.now,
    required this.lens,
    required this.day,
    required this.busy,
    required this.error,
    required this.onLens,
    required this.onDay,
    required this.onRecord,
    required this.onOpen,
    required this.onAdd,
  });

  final GardenSchedule schedule;
  final List<Plant> plants;
  final DateTime now;
  final _ChoreLens lens;
  final DateTime? day;
  final Set<String> busy;
  final String? error;
  final ValueChanged<_ChoreLens> onLens;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<GardenChore> onRecord;
  final ValueChanged<String> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(now);
    final focus = day ?? today;
    final all = [...schedule.overdue, ...schedule.today, ...schedule.later];
    final wateringNow = _wateringDue(all: all, plants: plants, now: now);
    final wateringNowIds = {for (final chore in wateringNow) chore.reminder.id};
    final visible = _visibleChores(
      schedule: schedule,
      all: all,
      lens: lens,
      focus: focus,
      now: now,
      wateringNow: wateringNow,
    );
    final dueTodayCount = _dueTodayCount(schedule, wateringNow);
    final week = _weekDays(today);
    final upcoming = _comingUp(
      schedule.later
          .where((chore) => !wateringNowIds.contains(chore.reminder.id))
          .toList(),
      today,
    );
    final showingToday = lens == _ChoreLens.today && _sameDay(focus, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HarmonyCard(
          done: careActionsToday(plants, now: now),
          openToday: dueTodayCount,
          watering: wateringNow.length,
          feeding: _count(all, ReminderTaskType.fertilize),
          pruning: _count(all, ReminderTaskType.prune),
        ),
        const SizedBox(height: AppSizes.sectionGap),
        _WeekStrip(
          days: week,
          selected: lens == _ChoreLens.today ? focus : null,
          chores: [
            ...all,
            for (final chore in wateringNow)
              if (choreWhen(chore.reminder.dueAt, now) == ChoreWhen.later)
                GardenChore(
                  reminder: Reminder(
                    id: chore.reminder.id,
                    plantId: chore.plant.id,
                    speciesId: chore.plant.speciesId,
                    taskType: ReminderTaskType.waterCheck,
                    title: chore.reminder.title,
                    dueAt: now,
                  ),
                  plant: chore.plant,
                ),
          ],
          phase: moonPhaseName(now),
          onDay: onDay,
        ),
        const SizedBox(height: 20),
        _Filters(
          lens: showingToday ? _ChoreLens.today : lens,
          dueCount: dueTodayCount,
          daySelected: day != null && !_sameDay(day!, today),
          onLens: onLens,
        ),
        const SizedBox(height: 20),
        _TaskSection(
          title: _sectionTitle(lens, focus, today),
          eyebrow: _sectionEyebrow(lens, focus),
          chores: visible,
          now: now,
          busy: busy,
          emptyTitle: _emptyTitle(lens, schedule),
          emptyBody: _emptyBody(lens, schedule),
          onOpen: onOpen,
          onRecord: onRecord,
        ),
        if (error case final message?) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: AppText.body.copyWith(color: AppColors.terracottaBright),
          ),
        ],
        const SizedBox(height: 20),
        _AddButton(onPressed: onAdd),
        if (showingToday && upcoming.isNotEmpty) ...[
          const SizedBox(height: AppSizes.sectionGap),
          _Upcoming(
            days: upcoming,
            now: now,
            onFullSchedule: () => onLens(_ChoreLens.all),
            onOpen: onOpen,
          ),
        ],
      ],
    );
  }
}

class _HarmonyCard extends StatelessWidget {
  const _HarmonyCard({
    required this.done,
    required this.openToday,
    required this.watering,
    required this.feeding,
    required this.pruning,
  });

  final int done;
  final int openToday;
  final int watering;
  final int feeding;
  final int pruning;

  @override
  Widget build(BuildContext context) {
    final total = done + openToday;
    // Nothing left due means the day's work is finished, even when the
    // list started empty.
    final fraction = total == 0 ? 1.0 : done / total;
    final percent = (fraction * 100).round();
    final headline = total == 0
        ? 'Nothing due today'
        : '$done of $total tasks complete';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlush,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY HARMONY',
                      style: AppText.eyebrow.copyWith(
                        color: AppColors.terracotta,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headline,
                      style: AppText.cardTitle.copyWith(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      AppIcons.choresSparkle,
                      width: 11,
                      height: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$percent% Done',
                      style: AppText.labelSemiBold.copyWith(
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: AppColors.surfaceClay,
                color: AppColors.green,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricPill(
                icon: AppIcons.choresDrop,
                label: 'Watering',
                value: watering == 0 ? 'Clear' : '$watering pending',
              ),
              const SizedBox(width: 8),
              _MetricPill(
                icon: AppIcons.choresSoil,
                label: 'Soil Vitality',
                value: feeding == 0 ? 'Rested' : '$feeding ready',
              ),
              const SizedBox(width: 8),
              _MetricPill(
                icon: AppIcons.choresPrune,
                label: 'Pruning',
                value: pruning == 0 ? 'None' : '$pruning upcoming',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SvgPicture.asset(icon, width: 12, height: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: AppText.labelMedium.copyWith(color: AppColors.body),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: AppText.title.copyWith(color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.selected,
    required this.chores,
    required this.phase,
    required this.onDay,
  });

  final List<DateTime> days;
  final DateTime? selected;
  final List<GardenChore> chores;
  final String phase;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final monday = days.first;
    final week = ((monday.day - 1) ~/ 7) + 1;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_months[monday.month - 1]} Ritual Moon • Week $week',
                style: AppText.fieldLabel.copyWith(color: AppColors.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              phase,
              style: AppText.labelSemiBold.copyWith(
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(width: 4),
            SvgPicture.asset(AppIcons.choresMoon, width: 9, height: 12),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < days.length; index++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == days.length - 1 ? 0 : 4,
                  ),
                  child: _DayButton(
                    day: days[index],
                    selected:
                        selected != null && _sameDay(days[index], selected!),
                    dots: _dotsFor(days[index], chores),
                    onTap: () => onDay(days[index]),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.selected,
    required this.dots,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final List<Color> dots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final letter = selected
        ? _weekdaysShort[day.weekday - 1]
        : _weekdayLetters[day.weekday - 1];
    final ink = selected ? AppColors.surface : AppColors.ink;
    final muted = selected
        ? AppColors.surface
        : AppColors.body.withValues(alpha: 0.8);

    return Material(
      color: selected ? AppColors.terracotta : AppColors.surfaceWarm,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: selected ? 10 : 8),
          child: Column(
            children: [
              Text(
                letter,
                style: (selected ? AppText.eyebrow : AppText.labelMedium)
                    .copyWith(color: selected ? ink : muted),
              ),
              SizedBox(height: selected ? 2 : 4),
              Text(
                '${day.day}',
                style: (selected ? AppText.title : AppText.titleSemiBold)
                    .copyWith(color: ink),
              ),
              SizedBox(height: selected ? 6 : 4),
              _Dots(colors: dots, large: selected, onDark: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.colors,
    required this.large,
    required this.onDark,
  });

  final List<Color> colors;
  final bool large;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final shown = colors.isEmpty
        ? [onDark ? AppColors.surface : AppColors.muted]
        : colors.take(2).toList();
    final size = large ? 6.0 : 4.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < shown.length; index++) ...[
          if (index > 0) SizedBox(width: large ? 4 : 2),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: shown[index],
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.lens,
    required this.dueCount,
    required this.daySelected,
    required this.onLens,
  });

  final _ChoreLens lens;
  final int dueCount;
  final bool daySelected;
  final ValueChanged<_ChoreLens> onLens;

  @override
  Widget build(BuildContext context) {
    final chips = [
      (_ChoreLens.today, 'Due Today ($dueCount)'),
      (_ChoreLens.all, 'All Chores'),
      (_ChoreLens.tomorrow, 'Tomorrow'),
      (_ChoreLens.weekend, 'This Weekend'),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = chips[index];
          final selected = !daySelected && lens == value;
          return Material(
            color: selected ? AppColors.terracotta : AppColors.surfaceBlush,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onLens(value),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Text(
                  label,
                  style: AppText.fieldLabel.copyWith(
                    color: selected ? AppColors.surface : AppColors.body,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.eyebrow,
    required this.chores,
    required this.now,
    required this.busy,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onOpen,
    required this.onRecord,
  });

  final String title;
  final String eyebrow;
  final List<GardenChore> chores;
  final DateTime now;
  final Set<String> busy;
  final String emptyTitle;
  final String emptyBody;
  final ValueChanged<String> onOpen;
  final ValueChanged<GardenChore> onRecord;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.cardTitle.copyWith(color: AppColors.ink),
                ),
              ),
              Text(
                eyebrow,
                style: AppText.eyebrow.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (chores.isEmpty)
          SectionMessage(title: emptyTitle, body: emptyBody)
        else
          for (var index = 0; index < chores.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _ChoreCard(
              chore: chores[index],
              now: now,
              isBusy: busy.contains(chores[index].reminder.id),
              onOpen: () => onOpen(chores[index].plant.id),
              onRecord: () => onRecord(chores[index]),
            ),
          ],
      ],
    );
  }
}

class _ChoreCard extends StatelessWidget {
  const _ChoreCard({
    required this.chore,
    required this.now,
    required this.isBusy,
    required this.onOpen,
    required this.onRecord,
  });

  final GardenChore chore;
  final DateTime now;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final reminder = chore.reminder;
    final canLog = careEventFor(reminder.taskType) != null;
    final dueToday = choreWhen(reminder.dueAt, now) != ChoreWhen.later;
    final tag = switch (reminder.taskType) {
      ReminderTaskType.fertilize => 'NUTRITION',
      ReminderTaskType.seasonalTask || ReminderTaskType.custom => 'RITUAL',
      _ => null,
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlush,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(
                  _taskIcon(reminder.taskType),
                  width: 16,
                  height: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            reminder.title,
                            style: AppText.titleSemiBold.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (dueToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.terracotta,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        if (tag != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: AppText.label.copyWith(
                                fontSize: 10,
                                height: 14 / 10,
                                letterSpacing: 0.5,
                                color: AppColors.amberInk,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(chore, now),
                      style: AppText.body.copyWith(color: AppColors.body),
                    ),
                    if (reminder.instructions case final hint?) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            AppIcons.choresHint,
                            width: 11,
                            height: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hint,
                              style: AppText.label.copyWith(
                                color: AppColors.amberText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _PlantThumb(plant: chore.plant),
                  const SizedBox(height: 8),
                  _ChoreAction(
                    label: _choreActionLabel(
                      type: reminder.taskType,
                      canLog: canLog,
                      isBusy: isBusy,
                    ),
                    onPressed: isBusy ? null : onRecord,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoreAction extends StatelessWidget {
  const _ChoreAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceBlush,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: AppText.labelSemiBold.copyWith(color: AppColors.green),
          ),
        ),
      ),
    );
  }
}

class _PlantThumb extends ConsumerWidget {
  const _PlantThumb({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = plant.coverPhotoPath;
    final image = path == null
        ? null
        : ref.watch(plantCoverImageProvider(path));

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        color: AppColors.surfaceBlush,
        child: image == null
            ? Center(
                child: SvgPicture.asset(
                  AppIcons.growingSprout,
                  width: 22,
                  height: 22,
                ),
              )
            : Image(image: image, fit: BoxFit.cover),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 10),
            blurRadius: 15,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Material(
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(AppIcons.choresAdd, width: 18, height: 17),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Add Custom Chore or Ritual',
                    style: AppText.titleSemiBold.copyWith(
                      color: AppColors.surface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({
    required this.days,
    required this.now,
    required this.onFullSchedule,
    required this.onOpen,
  });

  final List<({DateTime day, List<GardenChore> chores})> days;
  final DateTime now;
  final VoidCallback onFullSchedule;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _upcomingTitle(days.first.day, now),
                  style: AppText.cardTitle.copyWith(color: AppColors.ink),
                ),
              ),
              TextButton(
                onPressed: onFullSchedule,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.terracotta,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Full Schedule',
                  style: AppText.label.copyWith(color: AppColors.terracotta),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < days.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _UpcomingCard(entry: days[index], onOpen: onOpen),
        ],
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.entry, required this.onOpen});

  final ({DateTime day, List<GardenChore> chores}) entry;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final chore = entry.chores.first;
    final extra = entry.chores.length - 1;
    final ritual = _isRitual(chore);

    return Material(
      color: AppColors.surfaceWarm,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onOpen(chore.plant.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlush,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdaysShort[entry.day.weekday - 1],
                      style: AppText.label.copyWith(
                        fontSize: 10,
                        height: 12 / 10,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      '${entry.day.day}',
                      style: AppText.title.copyWith(
                        height: 16 / 16,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chore.reminder.title,
                            style: AppText.titleSemiBold.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          ritual ? 'Ritual' : _partOfDay(chore.reminder.dueAt),
                          style: AppText.labelSemiBold.copyWith(
                            color: ritual
                                ? AppColors.amberText
                                : AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      extra == 0
                          ? '${chore.plant.displayName} · ${_place(chore.plant)}'
                          : '${chore.plant.displayName} · and $extra more',
                      style: AppText.body.copyWith(color: AppColors.body),
                    ),
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

class _CustomChoreSheet extends ConsumerStatefulWidget {
  const _CustomChoreSheet({required this.plants});

  final List<Plant> plants;

  @override
  ConsumerState<_CustomChoreSheet> createState() => _CustomChoreSheetState();
}

class _CustomChoreSheetState extends ConsumerState<_CustomChoreSheet> {
  final _title = TextEditingController();
  late String? _plantId = widget.plants.isEmpty ? null : widget.plants.first.id;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final plantId = _plantId;
    if (title.isEmpty || plantId == null) {
      setState(() => _error = 'Name the chore and choose a plant.');
      return;
    }
    final plant = widget.plants.firstWhere((item) => item.id == plantId);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(reminderRepositoryProvider)
          .createManual(
            Reminder(
              id: '',
              plantId: plant.id,
              speciesId: plant.speciesId,
              taskType: ReminderTaskType.custom,
              title: title,
              dueAt: DateTime.now(),
              schedule: const ReminderSchedule(mode: ScheduleMode.manual),
            ),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom chore',
            style: AppText.cardTitle.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            widget.plants.isEmpty
                ? 'Add a plant to your garden before writing a chore for it.'
                : 'It shows up under Due Today, on the plant you choose.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
          if (widget.plants.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.input.copyWith(color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Chore'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _plantId,
              decoration: const InputDecoration(labelText: 'Plant'),
              items: [
                for (final plant in widget.plants)
                  DropdownMenuItem(
                    value: plant.id,
                    child: Text(plant.displayName),
                  ),
              ],
              onChanged: (value) => setState(() => _plantId = value),
            ),
          ],
          if (_error case final message?) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: AppText.body.copyWith(color: AppColors.terracottaBright),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.plants.isEmpty || _saving ? null : _save,
              child: Text(_saving ? 'Saving' : 'Add to chores'),
            ),
          ),
        ],
      ),
    );
  }
}

List<GardenChore> _visibleChores({
  required GardenSchedule schedule,
  required List<GardenChore> all,
  required _ChoreLens lens,
  required DateTime focus,
  required DateTime now,
  required List<GardenChore> wateringNow,
}) {
  return switch (lens) {
    _ChoreLens.all => all,
    _ChoreLens.tomorrow =>
      all
          .where(
            (chore) => _sameDay(
              chore.reminder.dueAt,
              _dateOnly(now).add(const Duration(days: 1)),
            ),
          )
          .toList(),
    _ChoreLens.weekend =>
      all.where((chore) => _inThisWeekend(chore.reminder.dueAt, now)).toList(),
    _ChoreLens.today => _choresForDay(
      schedule: schedule,
      all: all,
      focus: focus,
      now: now,
      wateringNow: _sameDay(focus, now) ? wateringNow : const [],
    ),
  };
}

List<GardenChore> _choresForDay({
  required GardenSchedule schedule,
  required List<GardenChore> all,
  required DateTime focus,
  required DateTime now,
  required List<GardenChore> wateringNow,
}) {
  final listed = [
    if (_sameDay(focus, now)) ...schedule.overdue,
    ...all.where((chore) => _sameDay(chore.reminder.dueAt, focus)),
  ];
  final ids = {for (final chore in listed) chore.reminder.id};
  return [
    ...listed,
    ...wateringNow.where((chore) => !ids.contains(chore.reminder.id)),
  ];
}

/// Watering that still needs doing today: a due water reminder, a plant whose
/// next watering has arrived, or a plant that has never been watered.
List<GardenChore> _wateringDue({
  required List<GardenChore> all,
  required List<Plant> plants,
  required DateTime now,
}) {
  final chores = <GardenChore>[];
  final covered = <String>{};
  for (final chore in all) {
    if (chore.reminder.taskType != ReminderTaskType.waterCheck) {
      continue;
    }
    final scheduled = choreWhen(chore.reminder.dueAt, now) != ChoreWhen.later;
    if (scheduled || _needsWatering(chore.plant, now)) {
      chores.add(chore);
      covered.add(chore.plant.id);
    }
  }
  for (final plant in plants) {
    if (covered.contains(plant.id) || !_needsWatering(plant, now)) {
      continue;
    }
    chores.add(
      GardenChore(
        reminder: Reminder(
          id: 'water:${plant.id}',
          plantId: plant.id,
          speciesId: plant.speciesId,
          taskType: ReminderTaskType.waterCheck,
          title: 'Water ${plant.displayName}',
          dueAt: now,
        ),
        plant: plant,
      ),
    );
  }
  return chores;
}

bool _needsWatering(Plant plant, DateTime now) {
  final next = plant.nextActions.nextWaterCheckAt;
  if (next != null) {
    return !next.isAfter(now);
  }
  return plant.currentCare.lastWateredAt == null;
}

int _dueTodayCount(GardenSchedule schedule, List<GardenChore> wateringNow) {
  final ids = {
    for (final chore in [...schedule.today, ...schedule.overdue])
      chore.reminder.id,
  };
  final extra = wateringNow
      .where((chore) => !ids.contains(chore.reminder.id))
      .length;
  return ids.length + extra;
}

String _choreActionLabel({
  required ReminderTaskType type,
  required bool canLog,
  required bool isBusy,
}) {
  if (isBusy) {
    return 'Saving';
  }
  if (type == ReminderTaskType.waterCheck) {
    return 'Water';
  }
  return canLog ? 'Done' : 'Skip';
}

String _sectionTitle(_ChoreLens lens, DateTime focus, DateTime today) {
  return switch (lens) {
    _ChoreLens.all => 'All Chores',
    _ChoreLens.tomorrow => 'Tomorrow',
    _ChoreLens.weekend => 'This Weekend',
    _ChoreLens.today =>
      _sameDay(focus, today)
          ? 'Due Today'
          : 'Due ${_weekdayNames[focus.weekday - 1]}',
  };
}

String _sectionEyebrow(_ChoreLens lens, DateTime focus) {
  return switch (lens) {
    _ChoreLens.today => _weekdays[focus.weekday - 1],
    _ChoreLens.tomorrow => 'NEXT DAY',
    _ChoreLens.weekend => 'SATURDAY & SUNDAY',
    _ChoreLens.all => 'OPEN',
  };
}

String _emptyTitle(_ChoreLens lens, GardenSchedule schedule) {
  if (!schedule.hasPlants) {
    return 'No plants yet';
  }
  if (schedule.isEmpty) {
    return 'Nothing on the schedule';
  }
  return switch (lens) {
    _ChoreLens.today => 'Nothing due',
    _ChoreLens.tomorrow => 'Tomorrow is clear',
    _ChoreLens.weekend => 'Weekend is clear',
    _ChoreLens.all => 'Nothing on the schedule',
  };
}

String _emptyBody(_ChoreLens lens, GardenSchedule schedule) {
  if (!schedule.hasPlants) {
    return 'Add a plant to your garden, then add it to chores from its page.';
  }
  if (schedule.isEmpty) {
    return 'Open a plant and add it to chores. Its care rhythm shows up here.';
  }
  return switch (lens) {
    _ChoreLens.today =>
      'Nothing is due this day. Later chores are listed below.',
    _ChoreLens.tomorrow => 'Nothing is due tomorrow.',
    _ChoreLens.weekend => 'Nothing is scheduled this weekend.',
    _ChoreLens.all => 'Open a plant and add it to chores.',
  };
}

/// The next few days that still have open chores, soonest first.
List<({DateTime day, List<GardenChore> chores})> _comingUp(
  List<GardenChore> later,
  DateTime today,
) {
  final grouped = <DateTime, List<GardenChore>>{};
  for (final chore in later) {
    final day = _dateOnly(chore.reminder.dueAt);
    if (day.isAfter(today)) {
      grouped.putIfAbsent(day, () => []).add(chore);
    }
  }
  final days = grouped.keys.toList()..sort();
  return [for (final day in days.take(4)) (day: day, chores: grouped[day]!)];
}

String _upcomingTitle(DateTime first, DateTime now) {
  final sunday = _monday(now).add(const Duration(days: 6));
  if (!first.isAfter(sunday)) {
    return 'Upcoming Later This Week';
  }
  return 'Coming Up';
}

int _count(List<GardenChore> chores, ReminderTaskType type) {
  return chores.where((chore) => chore.reminder.taskType == type).length;
}

bool _isRitual(GardenChore chore) {
  return chore.reminder.taskType == ReminderTaskType.seasonalTask ||
      chore.reminder.taskType == ReminderTaskType.custom;
}

String _taskIcon(ReminderTaskType type) => switch (type) {
  ReminderTaskType.waterCheck => AppIcons.choresDrop,
  ReminderTaskType.fertilize => AppIcons.choresSoil,
  ReminderTaskType.prune => AppIcons.choresPrune,
  ReminderTaskType.pestCheck => AppIcons.choresHint,
  ReminderTaskType.seasonalTask => AppIcons.choresRitual,
  _ => AppIcons.choresMark,
};

String _subtitle(GardenChore chore, DateTime now) {
  final due = chore.reminder.dueAt;
  final needsWater =
      chore.reminder.taskType == ReminderTaskType.waterCheck &&
      _needsWatering(chore.plant, now);
  final when = needsWater
      ? 'Due today'
      : choreWhen(due, now) == ChoreWhen.later
      ? dueLabel(due, now: now)
      : formatTimeLabel(due);
  return '$when · ${chore.plant.displayName} · ${_place(chore.plant)}';
}

String _place(Plant plant) {
  final spot = GardenSpot.fromWire(plant.gardenId);
  if (spot != null) {
    return gardenSpotLabel(spot);
  }
  return switch (plant.locationType) {
    LocationType.indoor => 'Indoors',
    LocationType.outdoor => 'Outdoors',
    LocationType.greenhouse => 'Greenhouse',
    LocationType.other => 'Unplaced',
  };
}

String _partOfDay(DateTime time) => switch (time.hour) {
  < 12 => 'Morning',
  < 18 => 'Afternoon',
  _ => 'Evening',
};

/// Name of the moon phase for [date], counted from the new moon of 6 Jan 2000.
String moonPhaseName(DateTime date) {
  const cycle = 29.530588853;
  final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
  final days = date.toUtc().difference(knownNewMoon).inMinutes / 1440;
  final age = days % cycle;
  final index = (age / cycle * 8).floor() % 8;
  return const [
    'New Moon',
    'Waxing Crescent',
    'First Quarter',
    'Waxing Gibbous',
    'Full Moon',
    'Waning Gibbous',
    'Last Quarter',
    'Waning Crescent',
  ][index];
}

List<Color> _dotsFor(DateTime day, List<GardenChore> chores) {
  final colors = <Color>[];
  for (final chore in chores) {
    if (!_sameDay(chore.reminder.dueAt, day)) {
      continue;
    }
    final color = switch (chore.reminder.taskType) {
      ReminderTaskType.waterCheck => AppColors.green,
      ReminderTaskType.fertilize => AppColors.terracotta,
      ReminderTaskType.seasonalTask ||
      ReminderTaskType.custom => AppColors.amberText,
      _ => AppColors.muted,
    };
    if (!colors.contains(color)) {
      colors.add(color);
    }
  }
  return colors;
}

bool _inThisWeekend(DateTime due, DateTime now) {
  final saturday = _monday(now).add(const Duration(days: 5));
  final sunday = saturday.add(const Duration(days: 1));
  final day = _dateOnly(due);
  return _sameDay(day, saturday) || _sameDay(day, sunday);
}

List<DateTime> _weekDays(DateTime today) {
  final monday = _monday(today);
  return [
    for (var offset = 0; offset < 7; offset++)
      monday.add(Duration(days: offset)),
  ];
}

DateTime _monday(DateTime day) {
  final date = _dateOnly(day);
  return date.subtract(Duration(days: date.weekday - 1));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _weekdays = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdaysShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
