import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/responsive.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/primer_step.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/skeletons.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The way in for a reader who has never read philosophy.
///
/// ## Why this is not just another list of entries
///
/// Every other screen in the product assumes you know what you are looking
/// for. This one assumes you do not, and that the honest first move is to
/// teach the small number of things that make the rest readable: what a claim
/// is, what an argument is, why validity is not truth, and why disagreement is
/// what a healthy discipline looks like.
///
/// It is ordered, and each step ends by handing the reader entries where the
/// thing just explained is being done — so the primer runs out and the corpus
/// takes over, rather than becoming a place to stay.
class PrimerScreen extends ConsumerWidget {
  const PrimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corpus = ref.watch(corpusProvider);
    final language = ref.watch(activeLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(AppL10n.of(context).primerTitle),
        backgroundColor: Colors.transparent,
      ),
      body: LamplightBackdrop(
        child: corpus.when(
          loading: ListSkeleton.new,
          error: (error, stack) => ErrorView(
            details: error.toString(),
            onRetry: () => ref.invalidate(corpusProvider),
          ),
          data: (data) => _body(context, data, language),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    KnowledgeBase corpus,
    AppLanguage language,
  ) {
    final l10n = AppL10n.of(context);
    final steps = corpus.primer;

    return SafeArea(
      child: ContentColumn(
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.gutterFor(context),
            Spacing.md,
            ResponsiveLayout.gutterFor(context),
            Spacing.xxxl,
          ),
          // One extra for the introduction above the steps.
          itemCount: steps.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ReadingColumn(
                alignToStart: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xl),
                  child: Text(
                    l10n.primerIntro,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            final step = steps[index - 1];
            return EntranceAnimation(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xl),
                child: _StepCard(
                  step: step,
                  number: index,
                  total: steps.length,
                  corpus: corpus,
                  language: language,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One step: the teaching, then where to see it done.
class _StepCard extends StatefulWidget {
  const _StepCard({
    required this.step,
    required this.number,
    required this.total,
    required this.corpus,
    required this.language,
  });

  final PrimerStep step;
  final int number;
  final int total;
  final KnowledgeBase corpus;
  final AppLanguage language;

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  /// The first step is open; the rest wait to be asked for.
  ///
  /// A path of nine full steps shown at once is a wall of text, and a reader
  /// who has never read philosophy is exactly the reader a wall of text turns
  /// away. Opening the first means the screen is never a list of closed doors.
  late bool _open = widget.number == 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final step = widget.step;
    final language = widget.language;
    final question = step.question;
    final reads = step.reads.map(widget.corpus.resolve).nonNulls.toList();

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.surfaceRadius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.primerStepLabel(widget.number, widget.total),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      step.title.resolve(language),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: Motion.duration(context, MotionTokens.quick),
                sizeCurve: MotionTokens.standard,
                crossFadeState: _open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: Spacing.md),
                    Text(
                      step.body.resolve(language),
                      style: AppTypography.reading(
                        step.body.resolvedLanguage(language),
                      ).copyWith(color: theme.colorScheme.onSurface),
                    ),
                    if (question != null) ...<Widget>[
                      const SizedBox(height: Spacing.lg),
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          borderRadius: Radii.cardRadius,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Text(
                          question.resolve(language),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    if (reads.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Spacing.lg),
                      SectionHeader(title: l10n.primerReadOn),
                      for (final entity in reads)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.sm),
                          child: EntityCard(
                            title: entity.name.resolve(language),
                            summary: entity.oneLine.resolve(language),
                            onTap: () => context.push(entity.ref.route),
                          ),
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
