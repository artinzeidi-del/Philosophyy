import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glow_segments.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/responsive.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/core/format/number_format.dart';
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
  const ExploreScreen({this.initialAxis, this.initialTermId, super.key});

  /// Which axis to open on, when arriving from a link that chose one.
  ///
  /// Home offers branches and traditions as entry points, and a chip there
  /// that dropped the reader into an unfiltered Explore would be a link that
  /// forgot what was clicked.
  final String? initialAxis;

  /// The taxonomy term to pre-select, when arriving from such a link.
  final String? initialTermId;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  /// Which vocabulary the reader is browsing by.
  ///
  /// The taxonomy has always had two axes and the screen only offered one. A
  /// reader who wants aesthetics, or philosophy of psychology, or political
  /// philosophy — the way people actually arrive at philosophy — had no way to
  /// ask: twenty-six branches were authored, labelled in both languages, and
  /// unreachable, with a `homeBrowseByBranch` string sitting unused in the ARB
  /// file as evidence that somebody had meant to build this.
  late _BrowseAxis _axis = widget.initialAxis == 'branch'
      ? _BrowseAxis.branch
      : _BrowseAxis.tradition;

  /// The selected term, as a taxonomy id. A string rather than a typed value
  /// because the vocabulary is content — see [Taxonomy].
  late String? _termId = widget.initialTermId;

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
    final selected = _termId;
    final byBranch = _axis == _BrowseAxis.branch;

    /// The terms an entity is filed under on the current axis.
    Set<String> termsOfPhilosopher(Philosopher philosopher) =>
        byBranch ? philosopher.branches : philosopher.traditions;

    // Selecting a broad term keeps the entries filed under narrower ones:
    // choosing "Indigenous" must not hide the Mesoamerican entries, and the
    // same holds for a branch with sub-branches beneath it.
    final philosophers = corpus.philosophersChronologically
        .where(
          (philosopher) =>
              selected == null ||
              termsOfPhilosopher(philosopher)
                  .any((id) => taxonomy.isUnder(id, selected)),
        )
        .toList();

    // Chronological, like the philosophers above and for the same reason: the
    // order in which the arguments were made is the useful order.
    final works = corpus.worksChronologically.where((work) {
      if (selected == null) return true;
      final terms = byBranch ? work.branches : corpus.traditionsOf(work);
      return terms.any((id) => taxonomy.isUnder(id, selected));
    }).toList();

    // Schools were missing from this screen entirely. Twenty-nine of them
    // carry full articles, and the only ways to one were to search for it by
    // name or to already be reading a philosopher who belongs to it — neither
    // of which helps the reader who wants to know what schools the Hellenistic
    // world produced, which is the question this screen exists to answer.
    final schools = corpus.schools.where((school) {
      if (selected == null) return true;
      final terms = byBranch ? school.branches : school.traditions;
      return terms.any((id) => taxonomy.isUnder(id, selected));
    }).toList();

    // Concepts are filtered too rather than being hidden whenever a filter is
    // on. Under a branch they are often the best answer to the query — a
    // reader who asks for aesthetics wants Rasa as much as Abhinavagupta.
    final concepts = corpus.concepts.where((concept) {
      if (selected == null) return true;
      final terms = byBranch ? concept.branches : concept.traditions;
      return terms.any((id) => taxonomy.isUnder(id, selected));
    }).toList();

    // Sorting goes through the taxonomy so the chips follow the editorial
    // order in the content file rather than the order entries happen to have
    // been authored in. Which terms are offered at all is settled by
    // [_representedTermsProvider], which does not change when a chip is
    // tapped and so is not recomputed when one is.
    final represented = ref.watch(_representedTermsProvider(byBranch));
    final terms = represented.map((id) => taxonomy[id]).nonNulls.toList()
      ..sort();

    return SafeArea(
      // Cards are not body text, so they get the content measure rather than
      // the reading measure — wide enough to use a tablet, capped so a card on
      // a large monitor does not put its date and its summary a head-turn
      // apart. On a phone the cap is infinite and this is a no-op.
      child: ContentColumn(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionHeader(
                      title: byBranch
                          ? l10n.homeBrowseByBranch
                          : l10n.homeBrowseByTradition,
                    ),
                    _AxisSwitch(
                      axis: _axis,
                      onChanged: (axis) => setState(() {
                        _axis = axis;
                        // The selection is dropped rather than carried over: a
                        // tradition id means nothing on the branch axis, and
                        // silently keeping a filter the chips no longer show
                        // would leave the reader looking at a narrowed screen
                        // with no visible reason for it.
                        _termId = null;
                      }),
                    ),
                    const SizedBox(height: Spacing.md),
                    _TaxonomyFilter(
                      terms: terms,
                      selectedId: selected,
                      language: language,
                      onSelected: (id) => setState(() => _termId = id),
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
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
                    maxSummaryLines: ResponsiveLayout.summaryLines(context),
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

            // Schools before ideas and after works: a school is a group of
            // people, so it sits nearer the people than the abstractions.
            if (schools.isNotEmpty) ...<Widget>[
              _HeaderSliver(title: l10n.sectionSchools),
              _CardSliver(
                count: schools.length,
                builder: (context, index) {
                  final school = schools[index];
                  return EntityCard(
                    title: school.name.resolve(language),
                    summary: school.oneLine.resolve(language),
                    maxSummaryLines: ResponsiveLayout.summaryLines(context),
                    meta: AppDates.range(school.period, language, l10n),
                    tags: <String>[
                      for (final branch in school.branches.take(2))
                        taxonomy.nameOf(branch).resolve(language),
                    ],
                    onTap: () => context.push(school.ref.route),
                  );
                },
              ),
            ],

            if (concepts.isNotEmpty) ...<Widget>[
              _HeaderSliver(title: l10n.sectionConcepts),
              _CardSliver(
                count: concepts.length,
                builder: (context, index) {
                  final concept = concepts[index];
                  return EntityCard(
                    title: concept.name.resolve(language),
                    summary: concept.oneLine.resolve(language),
                    maxSummaryLines: ResponsiveLayout.summaryLines(context),
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
      ),
    );
  }
}

/// Which of the taxonomy's two vocabularies the reader is browsing by.
enum _BrowseAxis {
  /// Where and when the philosophy was done.
  tradition,

  /// What the philosophy is about.
  branch,
}

/// The taxonomy terms that actually have entries behind them, per axis.
///
/// Only terms with something filed under them are offered as chips, so a
/// filter can never lead to an empty screen — and a broad term earns its chip
/// from the entries filed beneath it, which is why every term's ancestry goes
/// in too.
///
/// ## Why this is a provider and not four lines in `build`
///
/// It was computed inline, and it depends on the axis and on nothing else —
/// not on the selected term, not on anything a reader can change without
/// changing axis. So it was being rebuilt from the whole corpus every time a
/// filter chip was tapped, for a result that could not have changed. Timed
/// against the shipped content that is 290µs of the frame, thrown away, on
/// every tap; at the size this product intends to reach it is worse than that,
/// because it walks every philosopher and every concept.
///
/// Keyed on a `bool` rather than on [_BrowseAxis] only because a family key has
/// to be comparable across rebuilds and a private enum is awkward to expose;
/// `true` is the branch axis.
final _representedTermsProvider = Provider.family<Set<String>, bool>((
  ref,
  byBranch,
) {
  final corpus = ref.watch(corpusProvider).value;
  if (corpus == null) return const <String>{};
  final taxonomy = corpus.taxonomy;
  return <String>{
    for (final philosopher in corpus.philosophers)
      for (final id in byBranch ? philosopher.branches : philosopher.traditions)
        ...taxonomy.ancestryOf(id),
    if (byBranch)
      for (final concept in corpus.concepts)
        for (final id in concept.branches) ...taxonomy.ancestryOf(id),
  };
});

/// Chooses between browsing by tradition and browsing by branch.
///
/// A segmented control rather than a second chip row: the two axes are
/// alternatives, not filters that combine, and a control that looks like the
/// chips beneath it would suggest they do.
class _AxisSwitch extends StatelessWidget {
  const _AxisSwitch({required this.axis, required this.onChanged});

  final _BrowseAxis axis;
  final ValueChanged<_BrowseAxis> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: GlowSegments<_BrowseAxis>(
          segments: <GlowSegment<_BrowseAxis>>[
            GlowSegment<_BrowseAxis>(
              value: _BrowseAxis.tradition,
              label: l10n.browseByTraditionShort,
              icon: Icons.public_outlined,
            ),
            GlowSegment<_BrowseAxis>(
              value: _BrowseAxis.branch,
              label: l10n.browseByBranchShort,
              icon: Icons.account_tree_outlined,
            ),
          ],
          selected: axis,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// The taxonomy chips, shown a few at a time until the reader asks for more.
///
/// ## Why this is not simply a `Wrap`
///
/// It was, and that worked while eleven traditions had entries behind them.
/// Filling the corpus took that past thirty, and thirty-odd chips is eleven
/// rows on a phone — the whole first screen given to a control, with the list
/// it filters pushed entirely below the fold. The screen was measurably worse
/// for having more content in it, which is the wrong way round.
///
/// A horizontally scrolling strip is the other common answer and was rejected:
/// it hides most of the vocabulary behind a swipe, and the vocabulary is the
/// part worth seeing. Two rows and a count says what is there and costs one tap
/// to open.
class _TaxonomyFilter extends StatefulWidget {
  const _TaxonomyFilter({
    required this.terms,
    required this.selectedId,
    required this.language,
    required this.onSelected,
  });

  final List<TaxonomyTerm> terms;
  final String? selectedId;
  final AppLanguage language;
  final ValueChanged<String?> onSelected;

  @override
  State<_TaxonomyFilter> createState() => _TaxonomyFilterState();
}

class _TaxonomyFilterState extends State<_TaxonomyFilter> {
  bool _expanded = false;

  /// Roughly how many chips fit in two rows at this width.
  ///
  /// An estimate rather than a measurement: chips are as wide as their labels,
  /// so the true count differs per language and per row. Getting it wrong
  /// costs a row of white space or a row of chips, and measuring properly
  /// would mean laying the whole set out invisibly first — a real cost for a
  /// control whose point is that it is cheap.
  static int _collapsedCount(BuildContext context) =>
      switch (ResponsiveLayout.sizeOf(context)) {
        WindowSize.compact => 7,
        WindowSize.medium => 14,
        WindowSize.expanded => 20,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final all = widget.terms;
    final limit = _collapsedCount(context);

    // A selected chip is always shown, wherever it falls in the list. Hiding
    // the active filter behind "more" leaves a screen that is filtered for a
    // reason the reader cannot see and cannot undo.
    final visible = _expanded || all.length <= limit
        ? all
        : <TaxonomyTerm>[
            ...all.take(limit),
            for (final term in all.skip(limit))
              if (term.id == widget.selectedId) term,
          ];
    final hidden = all.length - visible.length;

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        FilterChip(
          label: Text(l10n.filterAll),
          selected: widget.selectedId == null,
          onSelected: (_) => widget.onSelected(null),
        ),
        for (final term in visible)
          FilterChip(
            label: Text(term.name.resolve(widget.language)),
            selected: widget.selectedId == term.id,
            onSelected: (isSelected) =>
                widget.onSelected(isSelected ? term.id : null),
          ),
        if (hidden > 0)
          ActionChip(
            label: Text(
              AppNumbers.localizeDigits(
                l10n.filterShowMore(hidden),
                widget.language,
              ),
            ),
            avatar: const Icon(Icons.expand_more, size: 18),
            onPressed: () => setState(() => _expanded = true),
          )
        else if (_expanded && all.length > limit)
          ActionChip(
            label: Text(l10n.filterShowFewer),
            avatar: const Icon(Icons.expand_less, size: 18),
            onPressed: () => setState(() => _expanded = false),
          ),
      ],
    );
  }
}

/// A lazily built run of cards, laid out for the width it is given.
///
/// One column on a phone; two or three once there is room. A reference work
/// browsed on a tablet in a single narrow strip wastes most of the screen and
/// makes the reader scroll several times as far for the same list.
///
/// The grid is used only above the phone breakpoint. Below it the list keeps
/// its natural per-card height, because a phone shows one card at a time and
/// there is no ragged row to tidy.
class _CardSliver extends StatelessWidget {
  const _CardSliver({required this.count, required this.builder});

  final int count;
  final Widget Function(BuildContext, int) builder;

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.columnsFor(context);

    if (columns == 1) {
      return SliverPadding(
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

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: Spacing.md,
          crossAxisSpacing: Spacing.md,
          mainAxisExtent: EntityCard.gridExtent(context),
        ),
        itemCount: count,
        itemBuilder: (context, index) =>
            EntranceAnimation(index: index, child: builder(context, index)),
      ),
    );
  }
}

/// A section heading between two runs of cards.
class _HeaderSliver extends StatelessWidget {
  const _HeaderSliver({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xl, Spacing.lg, 0),
    sliver: SliverToBoxAdapter(child: SectionHeader(title: title)),
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
      maxSummaryLines: ResponsiveLayout.summaryLines(context),
      meta: AppDates.lifeSpan(philosopher.life, language, l10n),
      tags: <String>[
        for (final tradition in philosopher.traditions.take(2))
          taxonomy.nameOf(tradition).resolve(language),
      ],
      onTap: () => context.push(philosopher.ref.route),
    );
  }
}
