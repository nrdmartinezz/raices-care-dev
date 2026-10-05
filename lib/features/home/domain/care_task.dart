import 'package:flutter/widgets.dart';

import '../../../app/assets.dart';
import '../../../app/theme.dart';
import '../../care/domain/care_task_type.dart';

/// The kind of care a task asks for. Each category carries its own tag icon
/// and colour pair, so the tag chip renders straight from the enum.
enum CareCategory {
  hydration(
    label: 'Hydration',
    icon: AppIcons.tagHydration,
    iconSize: Size(8.667, 10.833),
    background: Color(0x80BCEDDA),
    foreground: AppColors.green,
  ),
  misting(
    label: 'Misting',
    icon: AppIcons.tagMisting,
    iconSize: Size(10.833, 10.843),
    background: Color(0x80BCEDDA),
    foreground: AppColors.green,
  ),
  rotation(
    label: 'Rotation',
    icon: AppIcons.tagRotation,
    iconSize: Size(9.723, 11.348),
    background: Color(0x4DFFDEAD),
    foreground: AppColors.amberText,
  ),
  cleaning(
    label: 'Cleaning',
    icon: AppIcons.tagCleaning,
    iconSize: Size(9.75, 11.917),
    background: Color(0x66FFDBCF),
    foreground: AppColors.terracotta,
  );

  const CareCategory({
    required this.label,
    required this.icon,
    required this.iconSize,
    required this.background,
    required this.foreground,
  });

  final String label;
  final String icon;
  final Size iconSize;
  final Color background;
  final Color foreground;

  /// Folds the eight scheduler task types into the four tags the design draws.
  ///
  /// Grouped by the gesture rather than the goal — repotting and feeding both
  /// mean handling the soil, pruning and pest checks both mean handling the
  /// leaves — so the colour still reads as a meaningful grouping rather than
  /// an arbitrary one. Add a tag icon to the design before splitting these.
  static CareCategory forTaskType(ReminderTaskType type) => switch (type) {
    ReminderTaskType.waterCheck => hydration,
    ReminderTaskType.fertilize || ReminderTaskType.repot => rotation,
    ReminderTaskType.prune ||
    ReminderTaskType.pestCheck ||
    ReminderTaskType.harvest => cleaning,
    ReminderTaskType.seasonalTask || ReminderTaskType.custom => misting,
  };
}

/// A single entry in Today's Ritual checklist.
class CareTask {
  const CareTask({
    required this.plantName,
    required this.time,
    required this.instruction,
    required this.category,
    required this.location,
    required this.isDone,
    this.isDueNow = false,
    this.plantId,
    this.reminderId,
    this.taskType,
  });

  final String plantName;
  final String time;
  final String instruction;
  final CareCategory category;
  final String location;
  final bool isDone;

  /// Set when the row can log care or open the plant.
  final String? plantId;
  final String? reminderId;
  final ReminderTaskType? taskType;

  /// Draws the timestamp in amber to mark the task as the one coming up.
  final bool isDueNow;
}
