import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/theme.dart';
import 'package:raices/features/learning/data/guide_repository.dart';
import 'package:raices/features/learning/domain/guide_catalog.dart';
import 'package:raices/features/learning/domain/learning_guide.dart';
import 'package:raices/features/learning/presentation/guide_feedback.dart';
import 'package:raices/features/learning/presentation/guide_screen.dart';

const _editorialPhrases = [
  'Cursor implementation contract',
  'Implementation notes',
  'log_sowing',
  'learn_transplant_readiness',
];

const _privateQueryKeys = [
  'email',
  'uid',
  'user',
  'user_id',
  'name',
  'latitude',
  'longitude',
  'location',
  'garden',
  'token',
  'notes',
];

late final GuideCatalog bundledGuides;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Widget tests run under fake async, where rootBundle.loadString does not
  // complete. Load the asset once in real async and reuse that catalog.
  setUpAll(() async {
    bundledGuides = await const GuideRepository().load();
  });

  test('loads the four draft guides in sequence', () async {
    final catalog = await const GuideRepository().load();
    final guides = catalog.guides;

    expect(guides.map((guide) => guide.id), [
      'learn_growing_space',
      'learn_plant_stages',
      'learn_seed_packets',
      'learn_start_seeds',
    ]);
    expect(guides.map((guide) => guide.slug), [
      'understand-your-growing-space',
      'understand-plant-stages',
      'read-a-seed-packet-or-plant-label',
      'start-seeds',
    ]);
    expect(guides.map((guide) => guide.nextGuideId), [
      'learn_plant_stages',
      'learn_seed_packets',
      'learn_start_seeds',
      null,
    ]);
    expect(catalog.nextGuide(guides[0])?.id, 'learn_plant_stages');
    expect(catalog.nextGuide(guides[1])?.id, 'learn_seed_packets');
    expect(catalog.nextGuide(guides[2])?.id, 'learn_start_seeds');
    expect(catalog.nextGuide(guides[3]), isNull);

    for (final guide in guides) {
      expect(guide.status, GuideStatus.draft);
      expect(guide.version, 1);
      expect(guide.reviewedAt, isNull);
      expect(guide.sourceAccessedAt, '2026-11-02');
      expect(guide.audience, 'beginners');
      expect(guide.learningObjectives, isNotEmpty);
      expect(guide.sections, isNotEmpty);
      expect(guide.checklist, isNotEmpty);
      expect(guide.knowledgeCheck.question, isNotEmpty);
      expect(guide.knowledgeCheck.answer, isNotEmpty);
      expect(guide.sourceLinks, isNotEmpty);
      expect(guide.isLearnerVisible, isFalse);
    }

    expect(
      guides.expand((guide) => guide.sourceLinks).map((link) => link.url),
      containsAll(const [
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/raised-bed-gardens',
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/lighting-for-indoor-plants',
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-the-shade',
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/tips-for-climate-ready-gardening',
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/starting-seeds-indoors',
        'https://extension.oregonstate.edu/catalog/pub/em-9128-growing-vegetables-central-oregon',
        'https://extension.oregonstate.edu/gardening/techniques/collecting-storing-seeds-your-garden',
        'https://extension.oregonstate.edu/imported-publication/succession-planting',
        'https://extension.oregonstate.edu/catalog/em-9027-growing-your-own',
        'https://extension.umn.edu/about/our-stories/news/yard-and-garden-news/a-warm-weather-jump-on-seed-starting',
      ]),
    );
  });

  test('a missing next guide is not linked', () async {
    final catalog = await const GuideRepository().load();
    final guides = [...catalog.guides];
    guides[3] = guides[3].copyWith(nextGuideId: 'learn_transplant_readiness');
    final edited = GuideCatalog(guides);

    expect(edited.nextGuide(edited.guides[3]), isNull);
    expect(
      edited.guides.map((guide) => guide.id),
      isNot(contains('learn_transplant_readiness')),
    );
  });

  test('drafts stay out of the learner catalog', () async {
    final catalog = await const GuideRepository().load();
    final guide = catalog.guides.first;

    expect(catalog.published, isEmpty);
    expect(catalog.guideForLearner(guide.id), isNull);

    final reviewedDraft = guide.copyWith(reviewedAt: '2026-11-03');
    final unreviewed = guide.copyWith(status: GuideStatus.published);
    final published = guide.copyWith(
      status: GuideStatus.published,
      reviewedAt: '2026-11-03',
    );

    expect(GuideCatalog([reviewedDraft]).published, isEmpty);
    expect(GuideCatalog([unreviewed]).published, isEmpty);
    expect(GuideCatalog([published]).published.single.id, guide.id);
    expect(
      GuideCatalog([published]).guideForLearner(guide.id)?.reviewedAt,
      '2026-11-03',
    );
  });

  test('learner payload omits editorial implementation notes', () async {
    final bundle = await rootBundle.loadString(learningGuidesAsset);
    for (final phrase in _editorialPhrases) {
      expect(bundle, isNot(contains(phrase)));
    }

    final catalog = GuideCatalog(decodeGuides(bundle));
    final learnerText = [
      for (final guide in catalog.guides) ...[
        guide.id,
        guide.summary,
        guide.audience,
        ...guide.learningObjectives,
        for (final section in guide.sections) ...[
          section.title,
          section.body,
          ...section.sourceRefs,
        ],
        ...guide.checklist,
        guide.knowledgeCheck.question,
        guide.knowledgeCheck.answer,
        for (final source in guide.sourceLinks) ...[
          source.ref,
          source.publisher,
          source.title,
          source.url,
        ],
        guide.nextGuideId ?? '',
      ],
    ].join('\n');
    for (final phrase in _editorialPhrases) {
      expect(learnerText, isNot(contains(phrase)));
    }
  });

  test('decoder rejects an implementation field without echoing it', () {
    const notes = 'log_sowing and learn_transplant_readiness';
    expect(
      () => decodeGuides('[{"implementation_notes":"$notes","id":"x"}]'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            'Unknown guide field.',
            isNot(contains('log_sowing')),
            isNot(contains('learn_transplant_readiness')),
          ),
        ),
      ),
    );
  });

  test('feedback carries the guide id and version only', () {
    final uri = guideFeedbackUri(guideId: 'learn_growing_space', version: 1);

    expect(uri.path, endsWith('/issues/new'));
    expect(uri.queryParameters.keys, ['title', 'body']);
    expect(uri.queryParameters['title'], contains('learn_growing_space'));
    expect(uri.queryParameters['title'], contains('v1'));
    expect(
      uri.queryParameters['body'],
      contains('guide_id: learn_growing_space'),
    );
    expect(uri.queryParameters['body'], contains('version: 1'));
    for (final key in _privateQueryKeys) {
      expect(uri.queryParameters.containsKey(key), isFalse);
      expect(uri.query, isNot(contains('$key=')));
    }
  });

  testWidgets('guide screen shows learner content and a local checklist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final guide = bundledGuides.guides.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRaicesTheme(),
        home: Scaffold(body: GuideScreen(guide: guide)),
      ),
    );
    await tester.pump();

    expect(
      find.text(guide.learningObjectives.first, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(guide.checklist.first, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(guide.knowledgeCheck.question, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(guide.sourceLinks.first.title, skipOffstage: false),
      findsOneWidget,
    );
    for (final phrase in _editorialPhrases) {
      expect(find.textContaining(phrase, skipOffstage: false), findsNothing);
    }

    final checkbox = find.byType(Checkbox);
    await tester.ensureVisible(checkbox.first);
    await tester.tap(checkbox.first);
    await tester.pump();

    expect(tester.widget<Checkbox>(checkbox.first).value, isTrue);
  });

  testWidgets('a draft id does not open the lesson', (tester) async {
    final catalog = bundledGuides;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guideCatalogProvider.overrideWith((ref) async => catalog)],
        child: const MaterialApp(
          home: LearningGuidePage(guideId: 'learn_start_seeds'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('This guide is not available'), findsOneWidget);
    expect(find.text('What you will learn'), findsNothing);
    expect(find.textContaining('log_sowing'), findsNothing);
  });

  testWidgets('the wisdom list hides drafts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guideCatalogProvider.overrideWith((ref) => bundledGuides)],
        child: const MaterialApp(home: Scaffold(body: GuidesSection())),
      ),
    );
    await tester.pump();

    expect(find.text('BEGINNER GUIDES'), findsNothing);
    expect(find.text('Understand your growing space'), findsNothing);
  });

  testWidgets('the wisdom list shows a reviewed guide', (tester) async {
    final published = GuideCatalog([
      bundledGuides.guides.first.copyWith(
        status: GuideStatus.published,
        reviewedAt: '2026-11-03',
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guideCatalogProvider.overrideWith((ref) => published)],
        child: const MaterialApp(home: Scaffold(body: GuidesSection())),
      ),
    );
    await tester.pump();

    expect(find.text('BEGINNER GUIDES'), findsOneWidget);
    expect(find.text('Understand your growing space'), findsOneWidget);
    expect(find.text('Start seeds'), findsNothing);
  });
}
