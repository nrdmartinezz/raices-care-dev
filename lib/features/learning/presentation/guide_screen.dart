import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../data/guide_repository.dart';
import '../domain/guide_catalog.dart';
import '../domain/learning_guide.dart';
import 'guide_feedback.dart';

/// Opens one published guide. Drafts, including this package, stay unavailable.
class LearningGuidePage extends ConsumerWidget {
  const LearningGuidePage({super.key, required this.guideId});

  final String guideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(guideCatalogProvider);
    return catalog.when(
      loading: () => const ColoredBox(
        color: AppColors.canvas,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const GuideUnavailable(),
      data: (loaded) {
        final guide = loaded.guideForLearner(guideId);
        if (guide == null) {
          return const GuideUnavailable();
        }
        final next = loaded.nextGuide(guide);
        return GuideScreen(
          guide: guide,
          nextGuide: next != null && next.isLearnerVisible ? next : null,
        );
      },
    );
  }
}

class GuideUnavailable extends StatelessWidget {
  const GuideUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: ShellScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This guide is not available',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'It stays unpublished until an editor reviews it.',
              style: AppText.bodyLarge.copyWith(color: AppColors.body),
            ),
          ],
        ),
      ),
    );
  }
}

/// Learner view of one guide.
///
/// Checklist ticks stay in this widget. Finishing them does not write a care
/// plan or create a reminder.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.guide, this.nextGuide});

  final LearningGuide guide;
  final LearningGuide? nextGuide;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final Set<int> _checked = {};
  var _showAnswer = false;
  var _feedbackFailed = false;

  Future<void> _report() async {
    final uri = guideFeedbackUri(
      guideId: widget.guide.id,
      version: widget.guide.version,
    );
    setState(() => _feedbackFailed = false);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() => _feedbackFailed = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _feedbackFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;
    final next = widget.nextGuide;
    return Material(
      color: AppColors.canvas,
      child: ShellScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BEGINNER GUIDE',
              style: AppText.eyebrow.copyWith(color: AppColors.green),
            ),
            const SizedBox(height: 7),
            Text(
              guide.title,
              style: AppText.display.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              guide.summary,
              style: AppText.bodyLarge.copyWith(color: AppColors.body),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            Text(
              'What you will learn',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            for (final objective in guide.learningObjectives)
              _Bullet(text: objective),
            const SizedBox(height: AppSizes.sectionGap),
            for (var index = 0; index < guide.sections.length; index++) ...[
              Text(
                '${index + 1}. ${guide.sections[index].title}',
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                guide.sections[index].body,
                style: AppText.bodyLarge.copyWith(color: AppColors.body),
              ),
              const SizedBox(height: AppSizes.sectionGap),
            ],
            Text(
              'Completion checklist',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < guide.checklist.length; index++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.green,
                value: _checked.contains(index),
                title: Text(
                  guide.checklist[index],
                  style: AppText.bodyLarge.copyWith(color: AppColors.ink),
                ),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      _checked.add(index);
                    } else {
                      _checked.remove(index);
                    }
                  });
                },
              ),
            const SizedBox(height: AppSizes.sectionGap),
            Text(
              'Quick check',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              guide.knowledgeCheck.question,
              style: AppText.bodyLarge.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            if (_showAnswer)
              Text(
                guide.knowledgeCheck.answer,
                style: AppText.bodyLarge.copyWith(color: AppColors.body),
              )
            else
              TextButton(
                onPressed: () => setState(() => _showAnswer = true),
                child: Text(
                  'Show answer',
                  style: AppText.subtitleSemiBold.copyWith(
                    color: AppColors.terracotta,
                  ),
                ),
              ),
            const SizedBox(height: AppSizes.sectionGap),
            Text(
              'Sources',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            for (final source in guide.sourceLinks) ...[
              Text(
                source.title,
                style: AppText.subtitleBold.copyWith(color: AppColors.ink),
              ),
              Text(
                '${source.ref}. ${source.publisher}',
                style: AppText.body.copyWith(color: AppColors.body),
              ),
              Text(
                source.url,
                style: AppText.caption.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Sources read ${guide.sourceAccessedAt}. This guide is version ${guide.version}.',
              style: AppText.caption.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            if (next != null) ...[
              TextButton(
                onPressed: () {
                  context.pushNamed(
                    LearningGuideRoute.name,
                    pathParameters: {'guideId': next.id},
                  );
                },
                child: Text(
                  'Next: ${next.title}',
                  style: AppText.subtitleSemiBold.copyWith(
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: _report,
              child: Text(
                'Report feedback',
                style: AppText.subtitleSemiBold.copyWith(
                  color: AppColors.terracotta,
                ),
              ),
            ),
            if (_feedbackFailed)
              Text(
                'Feedback could not be opened.',
                style: AppText.body.copyWith(color: AppColors.terracottaBright),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: AppText.bodyLarge.copyWith(color: AppColors.green)),
          Expanded(
            child: Text(
              text,
              style: AppText.bodyLarge.copyWith(color: AppColors.body),
            ),
          ),
        ],
      ),
    );
  }
}

/// Published beginner guides on the Wisdom tab. Drafts leave this empty.
class GuidesSection extends ConsumerWidget {
  const GuidesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(guideCatalogProvider);
    return catalog.maybeWhen(
      data: (loaded) => _PublishedGuides(catalog: loaded),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PublishedGuides extends StatelessWidget {
  const _PublishedGuides({required this.catalog});

  final GuideCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final guides = catalog.published;
    if (guides.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BEGINNER GUIDES',
            style: AppText.eyebrow.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 8),
          for (final guide in guides)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  onTap: () {
                    context.pushNamed(
                      LearningGuideRoute.name,
                      pathParameters: {'guideId': guide.id},
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guide.title,
                          style: AppText.subtitleBold.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guide.summary,
                          style: AppText.body.copyWith(color: AppColors.body),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
