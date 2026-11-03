import 'dart:convert';

/// Draft lessons stay out of the learner catalog until an editor reviews them.
enum GuideStatus {
  draft('draft'),
  published('published');

  const GuideStatus(this.wire);

  final String wire;

  static GuideStatus parse(Object? wire) {
    if (wire is! String) {
      throw const FormatException('Unknown guide status.');
    }
    for (final status in GuideStatus.values) {
      if (status.wire == wire) {
        return status;
      }
    }
    throw const FormatException('Unknown guide status.');
  }
}

/// A cited source. The access date lives on the guide, not on each link.
class SourceLink {
  const SourceLink({
    required this.ref,
    required this.publisher,
    required this.title,
    required this.url,
  });

  final String ref;
  final String publisher;
  final String title;
  final String url;

  factory SourceLink.fromJson(Map<String, dynamic> json) {
    _rejectUnknown(json, _sourceKeys);
    return SourceLink(
      ref: _text(json, 'ref'),
      publisher: _text(json, 'publisher'),
      title: _text(json, 'title'),
      url: _url(json, 'url'),
    );
  }
}

/// One learner section, in catalog order.
class GuideSection {
  const GuideSection({
    required this.title,
    required this.body,
    required this.sourceRefs,
  });

  final String title;
  final String body;
  final List<String> sourceRefs;

  factory GuideSection.fromJson(Map<String, dynamic> json) {
    _rejectUnknown(json, _sectionKeys);
    return GuideSection(
      title: _text(json, 'title'),
      body: _text(json, 'body'),
      sourceRefs: _strings(json, 'source_refs'),
    );
  }
}

/// A single question shown after the lesson. The answer is learner-facing copy.
class KnowledgeCheck {
  const KnowledgeCheck({required this.question, required this.answer});

  final String question;
  final String answer;

  factory KnowledgeCheck.fromJson(Map<String, dynamic> json) {
    _rejectUnknown(json, _checkKeys);
    return KnowledgeCheck(
      question: _text(json, 'question'),
      answer: _text(json, 'answer'),
    );
  }
}

/// Learner-facing guide. Implementation notes are not fields on this type.
class LearningGuide {
  const LearningGuide({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.audience,
    required this.learningObjectives,
    required this.sections,
    required this.checklist,
    required this.knowledgeCheck,
    required this.nextGuideId,
    required this.sourceLinks,
    required this.status,
    required this.version,
    required this.reviewedAt,
    required this.sourceAccessedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String summary;
  final String audience;
  final List<String> learningObjectives;
  final List<GuideSection> sections;
  final List<String> checklist;
  final KnowledgeCheck knowledgeCheck;
  final String? nextGuideId;
  final List<SourceLink> sourceLinks;
  final GuideStatus status;
  final int version;

  /// Null until a human editor completes review. A source access date is not
  /// a review.
  final String? reviewedAt;

  /// When the cited pages were read. This does not publish the guide.
  final String sourceAccessedAt;

  /// Visible to learners only after editorial review.
  bool get isLearnerVisible =>
      status == GuideStatus.published &&
      reviewedAt != null &&
      reviewedAt!.isNotEmpty;

  LearningGuide copyWith({
    GuideStatus? status,
    String? reviewedAt,
    bool clearReviewedAt = false,
    String? nextGuideId,
    bool clearNextGuideId = false,
  }) {
    return LearningGuide(
      id: id,
      slug: slug,
      title: title,
      summary: summary,
      audience: audience,
      learningObjectives: learningObjectives,
      sections: sections,
      checklist: checklist,
      knowledgeCheck: knowledgeCheck,
      nextGuideId: clearNextGuideId ? null : (nextGuideId ?? this.nextGuideId),
      sourceLinks: sourceLinks,
      status: status ?? this.status,
      version: version,
      reviewedAt: clearReviewedAt ? null : (reviewedAt ?? this.reviewedAt),
      sourceAccessedAt: sourceAccessedAt,
    );
  }

  factory LearningGuide.fromJson(Map<String, dynamic> json) {
    _rejectUnknown(json, _guideKeys);
    final next = json['next_guide_id'];
    if (next != null && next is! String) {
      throw const FormatException('Guide field is invalid.');
    }
    if (!_has(json, 'next_guide_id') || !_has(json, 'reviewed_at')) {
      throw const FormatException('Guide field is missing.');
    }
    return LearningGuide(
      id: _text(json, 'id'),
      slug: _text(json, 'slug'),
      title: _text(json, 'title'),
      summary: _text(json, 'summary'),
      audience: _text(json, 'audience'),
      learningObjectives: _strings(json, 'learning_objectives'),
      sections: _objects(json, 'sections', GuideSection.fromJson),
      checklist: _strings(json, 'checklist'),
      knowledgeCheck: KnowledgeCheck.fromJson(_object(json, 'knowledge_check')),
      nextGuideId: next as String?,
      sourceLinks: _objects(json, 'source_links', SourceLink.fromJson),
      status: GuideStatus.parse(json['status']),
      version: _version(json['version']),
      reviewedAt: _dateOrNull(json['reviewed_at']),
      sourceAccessedAt: _date(_text(json, 'source_accessed_at')),
    );
  }
}

/// Decodes the learner catalog. Unknown keys are rejected so editorial notes
/// cannot ride along on an object and surface in the app.
List<LearningGuide> decodeGuides(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('Guide catalog must be a list.');
  }
  return [
    for (final entry in decoded)
      if (entry is Map<String, dynamic>)
        LearningGuide.fromJson(entry)
      else if (entry is Map)
        LearningGuide.fromJson(Map<String, dynamic>.from(entry))
      else
        throw const FormatException('Guide entry is invalid.'),
  ];
}

const _guideKeys = {
  'id',
  'slug',
  'title',
  'summary',
  'audience',
  'learning_objectives',
  'sections',
  'checklist',
  'knowledge_check',
  'next_guide_id',
  'source_links',
  'status',
  'version',
  'reviewed_at',
  'source_accessed_at',
};

const _sectionKeys = {'title', 'body', 'source_refs'};

const _sourceKeys = {'ref', 'publisher', 'title', 'url'};

const _checkKeys = {'question', 'answer'};

const _datePattern = r'^\d{4}-\d{2}-\d{2}$';

void _rejectUnknown(Map<String, dynamic> json, Set<String> allowed) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw const FormatException('Unknown guide field.');
    }
  }
}

bool _has(Map<String, dynamic> json, String key) => json.containsKey(key);

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Guide field is invalid.');
  }
  return value;
}

String _url(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw const FormatException('Guide field is invalid.');
  }
  return value;
}

List<String> _strings(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw const FormatException('Guide field is invalid.');
  }
  return [
    for (final entry in value)
      if (entry is String && entry.trim().isNotEmpty)
        entry
      else
        throw const FormatException('Guide field is invalid.'),
  ];
}

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw const FormatException('Guide field is invalid.');
}

List<T> _objects<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic> json) decode,
) {
  final value = json[key];
  if (value is! List) {
    throw const FormatException('Guide field is invalid.');
  }
  return [for (final entry in value) decode(_asMap(entry))];
}

Map<String, dynamic> _asMap(Object? entry) {
  if (entry is Map<String, dynamic>) {
    return entry;
  }
  if (entry is Map) {
    return Map<String, dynamic>.from(entry);
  }
  throw const FormatException('Guide field is invalid.');
}

int _version(Object? value) {
  if (value is! int) {
    throw const FormatException('Guide field is invalid.');
  }
  return value;
}

String? _dateOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const FormatException('Guide field is invalid.');
  }
  return _date(value);
}

String _date(String value) {
  if (!RegExp(_datePattern).hasMatch(value)) {
    throw const FormatException('Guide field is invalid.');
  }
  return value;
}
