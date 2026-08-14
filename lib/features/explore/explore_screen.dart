import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/skeletons.dart';
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
  /// The selected tradition, as a taxonomy id. A string rather than a typed
  /// value because the vocabulary is content — see [Taxonomy].
  String? _traditionId;

  @override
  Widget build(BuildContext context) {
    final corpus = ref.watch(corpusProvider);
    final language = ref.watch(activeLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LamplightBackdrop(
        intensity: 0.7,
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
    final taxonomy = corpus.taxonomy;
    final selected = _traditionId;

    // Selecting a broad tradition keeps the entries filed under narrower ones:
    // choosing "Indigenous" must not hide the Mesoamerican entries.
    final philosophers = corpus.philosophersChronologically
        .where(
          (philosopher) =>
              selected == null ||
              philosopher.traditions.any(
                (id) => taxonomy.isUnder(id, selected),
              ),
        )
        .toList();

    // Only traditions with philosophers behind them are offered, so a filter
    // can never lead to an empty screen — including the broader terms, which
    // earn their chip from the entries filed beneath them. Sorting goes through
    // the taxonomy so the chips follow the editorial order in the content file
    // rather than the order philosophers happen to have been authored in.
    // Chronological, like the philosophers above and for the same reason: the
    // order in which the arguments were made is the useful order.
    final works = corpus.worksChronologically.where((work) {
      if (selected == null) return true;
      final traditions = corpus.traditionsOf(work);
      return traditions.any((id) => taxonomy.isUnder(id, selected));
    }).toList();

    final represented = <String>{
      for (final philosopher in corpus.philosophers)
        for (final id in philosopher.traditions) ...taxonomy.ancestryOf(id),
    };
    final traditions = represented.map((id) => taxonomy[id]).nonNulls.toList()
      ..sort();

    return SafeArea(
      // Slivers rather than a ListView holding one tall Column.
      //
      // A `ListView(children: …)` wrapping a single Column builds every card in
      // the corpus on every frame, however far off screen it is. That is
      // invisible at fourteen works and fatal at ten thousand, and it is
      // exactly the kind of ceiling that never announces itself — the screen
      // just gets slower until someone profiles it. `SliverList.builder` builds
      // what is visible.
      //
      // [ReadingColumn] moves inside each item rather than wrapping the list,
      // because it only constrains width and so composes per row.
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xl,
              Spacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: ReadingColumn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionHeader(title: l10n.homeBrowseByTradition),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: <Widget>[
                        FilterChip(
                          label: Text(l10n.filterAll),
                          selected: selected == null,
                          onSelected: (_) =>
                              setState(() => _traditionId = null),
                        ),
                        for (final tradition in traditions)
                          FilterChip(
                            label: Text(tradition.name.resolve(language)),
                            selected: selected == tradition.id,
                            onSelected: (isSelected) => setState(
                              () => _traditionId = isSelected
                                  ? tradition.id
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
          ),

          _CardSliver(
            count: philosophers.length,
            builder: (context, index) => _PhilosopherRow(
              philosopher: philosophers[index],
              taxonomy: taxonomy,
              language: language,
            ),
          ),

          // Works are filtered by the same tradition the philosophers are, so
          // choosing a tradition narrows the whole screen rather than only its
          // first section.
          if (works.isNotEmpty) ...<Widget>[
            _HeaderSliver(title: l10n.exploreWorksSection),
            _CardSliver(
              count: works.length,
              builder: (context, index) {
                final work = works[index];
                return EntityCard(
                  title: work.name.resolve(language),
                  summary: work.oneLine.resolve(language),
                  meta: _workMeta(corpus, work, language, l10n),
                  tags: <String>[
                    for (final branch in work.branches.take(2))
                      taxonomy.nameOf(branch).resolve(language),
                  ],
                  onTap: () => context.push(work.ref.route),
                );
              },
            ),
          ],

          if (selected == null) ...<Widget>[
            _HeaderSliver(title: l10n.sectionConcepts),
            _CardSliver(
              count: corpus.concepts.length,
              builder: (context, index) {
                final concept = corpus.concepts[index];
                return EntityCard(
                  title: concept.name.resolve(language),
                  summary: concept.oneLine.resolve(language),
                  tags: <String>[
                    for (final branch in concept.branches.take(2))
                      taxonomy.nameOf(branch).resolve(language),
                  ],
                  onTap: () => context.push(concept.ref.route),
                );
              },
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxxl)),
        ],
      ),
    );
  }
}

/// A lazily built run of cards, held to the reading measure.
///
/// The entrance stagger is keyed on the index within the run, which is what
/// makes it survive lazy building: a card scrolled into view arrives with the
/// same motion whether it was built on the first frame or the fortieth.
class _CardSliver extends StatelessWidget {
  const _CardSliver({required this.count, required this.builder});

  final int count;
  final Widget Function(BuildContext, int) builder;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
    sliver: SliverList.builder(
      itemCount: count,
      itemBuilder: (context, index) => ReadingColumn(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: EntranceAnimation(
            index: index,
            child: builder(context, index),
          ),
        ),
      ),
    ),
  );
}

/// A section heading between two runs of cards.
class _HeaderSliver extends StatelessWidget {
  const _HeaderSliver({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xl, Spacing.lg, 0),
    sliver: SliverToBoxAdapter(
      child: ReadingColumn(child: SectionHeader(title: title)),
    ),
  );
}

/// The line above a work's title: who wrote it and when.
String? _workMeta(
  KnowledgeBase corpus,
  Work work,
  AppLanguage language,
  AppL10n l10n,
) {
  final author = corpus.philosopher(work.authorId);
  final composed = AppDates.range(work.composed, language, l10n);
  final parts = <String>[
    if (author != null) author.name.resolve(language),
    ?composed,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _PhilosopherRow extends StatelessWidget {
  const _PhilosopherRow({
    required this.philosopher,
    required this.taxonomy,
    required this.language,
  });

  final Philosopher philosopher;
  final Taxonomy taxonomy;
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
          taxonomy.nameOf(tradition).resolve(language),
      ],
      onTap: () => context.push(philosopher.ref.route),
    );
  }
}
