/// A species sowing calendar computed for one garden's frost dates.
class SowingCalendar {
  const SowingCalendar({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.daysToHarvest,
    required this.plans,
  });

  final String id;
  final String scientificName;
  final String commonName;
  final int? daysToHarvest;
  final List<SowingPlan> plans;

  bool get hasWindows => plans.any((plan) => plan.milestones.isNotEmpty);

  factory SowingCalendar.fromJson(Map<String, dynamic> json) {
    final plans = json['plans'];
    return SowingCalendar(
      id: json['id'] as String? ?? '',
      scientificName: json['scientificName'] as String? ?? '',
      commonName: json['commonName'] as String? ?? '',
      daysToHarvest: (json['daysToHarvest'] as num?)?.toInt(),
      plans: plans is List
          ? [
              for (final plan in plans)
                if (plan is Map)
                  SowingPlan.fromJson(plan.cast<String, dynamic>()),
            ]
          : const [],
    );
  }
}

class SowingPlan {
  const SowingPlan({required this.season, required this.milestones});

  final String season;
  final List<SowingMilestone> milestones;

  factory SowingPlan.fromJson(Map<String, dynamic> json) {
    final milestones = json['milestones'];
    return SowingPlan(
      season: json['season'] as String? ?? '',
      milestones: milestones is List
          ? [
              for (final milestone in milestones)
                if (milestone is Map)
                  SowingMilestone.fromJson(milestone.cast<String, dynamic>()),
            ]
          : const [],
    );
  }
}

class SowingMilestone {
  const SowingMilestone({
    required this.method,
    required this.start,
    required this.end,
  });

  final String method;
  final String start;
  final String end;

  factory SowingMilestone.fromJson(Map<String, dynamic> json) =>
      SowingMilestone(
        method: json['method'] as String? ?? '',
        start: json['start'] as String? ?? '',
        end: json['end'] as String? ?? '',
      );
}

/// Identifies the species whose sowing calendar we want.
class SowingRequest {
  const SowingRequest({required this.scientificName, this.commonName});

  final String scientificName;
  final String? commonName;

  @override
  bool operator ==(Object other) {
    return other is SowingRequest &&
        other.scientificName.toLowerCase() == scientificName.toLowerCase() &&
        other.commonName?.toLowerCase() == commonName?.toLowerCase();
  }

  @override
  int get hashCode =>
      Object.hash(scientificName.toLowerCase(), commonName?.toLowerCase());
}

String formatPlantingDay(String iso) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) return iso;
  return '${months[month - 1]} $day';
}

String formatPlantingRange(String start, String end) {
  if (start.isEmpty) return end;
  if (end.isEmpty || start == end) return formatPlantingDay(start);
  return '${formatPlantingDay(start)} – ${formatPlantingDay(end)}';
}

String sowingSeasonLabel(String season) => switch (season) {
  'spring' => 'Spring',
  'summer' => 'Summer',
  'fall' => 'Fall',
  'winter' => 'Winter',
  _ => season,
};

String sowingMethodLabel(String method) => switch (method) {
  'start_indoors' => 'Start indoors',
  'direct_sow' => 'Sow outdoors',
  'transplant' => 'Transplant',
  _ => method,
};
