import 'learning_guide.dart';

/// Ordered guides loaded from the learner payload.
///
/// [published] is the learner-facing list. A draft, or a published record
/// whose review date is still null, stays out of that list.
class GuideCatalog {
  GuideCatalog(List<LearningGuide> guides)
    : guides = List.unmodifiable(guides) {
    final ids = <String>{};
    for (final guide in this.guides) {
      if (!ids.add(guide.id)) {
        throw const FormatException('Duplicate guide id.');
      }
    }
  }

  final List<LearningGuide> guides;

  List<LearningGuide> get published => [
    for (final guide in guides)
      if (guide.isLearnerVisible) guide,
  ];

  /// The published guide with this id, or null when it is missing or still
  /// a draft.
  LearningGuide? guideForLearner(String id) {
    for (final guide in published) {
      if (guide.id == id) {
        return guide;
      }
    }
    return null;
  }

  /// The next guide in the loaded set. A null id, or an id that was never
  /// imported, resolves to null so the app does not link to a missing lesson.
  LearningGuide? nextGuide(LearningGuide guide) {
    final id = guide.nextGuideId;
    if (id == null) {
      return null;
    }
    for (final candidate in guides) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }
}
