import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Browsing, for readers who would rather look around than search.
///
/// Philosophers are listed in chronological order rather than alphabetically,
/// because the order in which people argued with each other is the single most
/// useful thing a newcomer can be shown about them, and an alphabetical list
/// puts Aristotle next to Beauvoir for no reason at all.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  Tradition? _tradition;

  @override
  Widget build(BuildContext context) {
    final corpus = ref.watch(corpusProvider);
    final language = ref.watch(activeLanguageProvider);

    return Scaffold(
      body: corpus.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          details: error.toString(),
          onRetry: () => ref.invalidate(corpusProvider),
        ),
        data: (data) => _body(context, data, language),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    KnowledgeBase corpus,
    AppLanguage language,
  ) {
    final l10n = AppL10n.of(context);
    final selected = _tradition;
    final philosophers = corpus.philosophersChronologically
        .where(
          (philosopher) =>
              selected == null || philosopher.traditions.contains(selected),
        )
        .toList();

    // Only traditions actually represented in the corpus are offered, so a
    // filter can never lead to an empty screen.
    final traditions =
        corpus.philosophers
            .expand((philosopher) => philosopher.traditions)
            .toSet()
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.xl,
          Spacing.lg,
          Spacing.xxxl,
        ),
        children: <Widget>[
          ReadingColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: l10n.homeBrowseByTradition),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: <Widget>[
                    FilterChip(
                      label: Text(l10n.navExplore),
                      selected: selected == null,
                      onSelected: (_) => setState(() => _tradition = null),
                    ),
                    for (final tradition in traditions)
                      FilterChip(
                        label: Text(
                          TaxonomyLabels.tradition(tradition).resolve(language),
                        ),
                        selected: selected == tradition,
                        onSelected: (isSelected) => setState(
                          () => _tradition = isSelected ? tradition : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.xxl),
                for (final philosopher in philosophers) ...<Widget>[
                  _PhilosopherRow(philosopher: philosopher, language: language),
                  const SizedBox(height: Spacing.md),
                ],
                if (selected == null) ...<Widget>[
                  const SizedBox(height: Spacing.xl),
                  SectionHeader(title: l10n.sectionConcepts),
                  for (final concept in corpus.concepts) ...<Widget>[
                    EntityCard(
                      title: concept.name.resolve(language),
                      summary: concept.oneLine.resolve(language),
                      tags: <String>[
                        for (final branch in concept.branches.take(2))
                          TaxonomyLabels.branch(branch).resolve(language),
                      ],
                      onTap: () => context.push(concept.ref.route),
                    ),
                    const SizedBox(height: Spacing.md),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhilosopherRow extends StatelessWidget {
  const _PhilosopherRow({required this.philosopher, required this.language});

  final Philosopher philosopher;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return EntityCard(
      title: philosopher.name.resolve(language),
      summary: philosopher.oneLine.resolve(language),
      meta: AppDates.lifeSpan(philosopher.life, language, l10n),
      tags: <String>[
        for (final tradition in philosopher.traditions.take(2))
          TaxonomyLabels.tradition(tradition).resolve(language),
      ],
      onTap: () => context.push(philosopher.ref.route),
    );
  }
}
