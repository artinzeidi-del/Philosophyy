import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/glow_segments.dart';
import 'package:philosophyy/core/design/gradients.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/core/format/bidi_text.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/core/search/text_normalizer.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/argument.dart';
import 'package:philosophyy/domain/entities/concept.dart';
import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/school.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';
import 'package:philosophyy/features/shared/argument_widgets.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/glossary_sheet.dart';
import 'package:philosophyy/features/shared/timeline_band.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/features/shared/up_button.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The article screen, used for every kind of entity.
///
/// Philosophers, concepts, works and schools share one screen rather than
/// having four, because they share the thing that matters: a title, a summary,
/// prose at a chosen depth, connections outward, and sources. What differs is
/// which extra sections appear, and that is a few lines of switch rather than
/// three more screens to keep consistent with each other.
class EntityScreen extends ConsumerStatefulWidget {
  const EntityScreen({required this.kind, required this.id, super.key});

  /// Which kind of entity to display.
  final EntityKind kind;

  /// The entity's identifier.
  final String id;

  @override
  ConsumerState<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends ConsumerState<EntityScreen> {
  /// The reader's depth for this entry, initialised from their level and then
  /// theirs to change for as long as the screen is open.
  ContentDepth? _depth;

  /// The depth to open [article] at for this reader.
  ///
  /// Clamped to what the article actually has, at both ends. Raising it was
  /// always here; lowering it was not, and the research reading level asks for
  /// a depth nothing in the corpus is authored at. The article read correctly
  /// — every section is visible at a depth past the last one written — but the
  /// depth control offers only the depths that exist, so its selection was not
  /// among its own segments and none of them was lit. The reader was given a
  /// control that had stopped saying where they were.
  static ContentDepth _openingDepth(Article article, WidgetRef ref) {
    final preferred = ref.read(settingsProvider).defaultDepth;
    final shallowest = article.shallowestAuthoredDepth;
    final deepest = article.deepestAuthoredDepth;
    if (preferred.order < shallowest.order) return shallowest;
    if (preferred.order > deepest.order) return deepest;
    return preferred;
  }

  @override
  Widget build(BuildContext context) {
    final corpus = ref.watch(corpusProvider);
    final language = ref.watch(activeLanguageProvider);
    final l10n = AppL10n.of(context);

    return corpus.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          details: error.toString(),
          onRetry: () => ref.invalidate(corpusProvider),
        ),
      ),
      data: (data) {
        final entity = data.resolve(EntityRef(widget.kind, widget.id));
        if (entity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyView(
              icon: Icons.search_off,
              title: l10n.notFoundTitle,
              body: l10n.notFoundBody,
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.backToHome),
              ),
            ),
          );
        }
        return _EntityBody(
          entity: entity,
          corpus: data,
          language: language,
          // The reader's level, raised to the shallowest level this entry
          // actually has. Their preference is a request for the least detail
          // they want; it is not a request for a blank page.
          depth: _depth ?? _openingDepth(entity.article, ref),
          onDepthChanged: (depth) => setState(() => _depth = depth),
        );
      },
    );
  }
}

class _EntityBody extends ConsumerStatefulWidget {
  const _EntityBody({
    required this.entity,
    required this.corpus,
    required this.language,
    required this.depth,
    required this.onDepthChanged,
  });

  final KnowledgeEntity entity;
  final KnowledgeBase corpus;
  final AppLanguage language;
  final ContentDepth depth;
  final ValueChanged<ContentDepth> onDepthChanged;

  @override
  ConsumerState<_EntityBody> createState() => _EntityBodyState();
}

class _EntityBodyState extends ConsumerState<_EntityBody> {
  final ScrollController _scrollController = ScrollController();

  /// Whether the reader has scrolled far enough that the real title has left
  /// the screen and the bar needs to carry it instead.
  bool _showCompactTitle = false;

  /// Roughly the height of the header block above the fold.
  static const double _titleHandoverOffset = 96;

  /// How long the reader must stop scrolling before the position is written.
  ///
  /// Writing on every scroll frame would hammer storage for no benefit; writing
  /// only on leave would lose the position if the app is killed. Settling for a
  /// moment is the signal that they have arrived somewhere worth remembering.
  static const Duration _positionSettleDelay = Duration(milliseconds: 700);

  Timer? _positionTimer;

  /// Where the reader last was, kept for a write made after teardown.
  double? _pendingOffset;

  /// Taken while the state is alive so the write on the way out needs no `ref`.
  late final LibraryController _library;

  @override
  void initState() {
    super.initState();
    _library = ref.read(libraryProvider.notifier);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  /// Returns the reader to where they left off, if they got far enough in.
  void _restorePosition() {
    if (!mounted || !_scrollController.hasClients) return;
    final saved = ref.read(libraryProvider).positionFor(widget.entity.ref);
    if (saved == null || !saved.isWorthRestoring) return;

    // Never scroll past the end: the article may be shorter than it was when
    // the position was recorded.
    final maximum = _scrollController.position.maxScrollExtent;
    final target = saved.scrollOffset.clamp(0.0, maximum);
    if (target <= 0) return;
    _scrollController.jumpTo(target);
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > _titleHandoverOffset;
    if (shouldShow != _showCompactTitle) {
      setState(() => _showCompactTitle = shouldShow);
    }

    // Kept as the scroll happens so that [_flushPosition] has something to
    // write after the controller it came from has been detached.
    _pendingOffset = _scrollController.offset;
    _positionTimer?.cancel();
    _positionTimer = Timer(_positionSettleDelay, _recordPosition);
  }

  /// Marks a passage the reader has selected.
  ///
  /// Offsets come from the rendered text, which is the text in whichever
  /// language actually resolved — so a highlight made while reading the English
  /// fallback of an untranslated section anchors against that English, and
  /// [Highlight.reanchoredIn] simply fails to place it if the reader later
  /// switches. Failing to place is the correct outcome: the passage they marked
  /// is genuinely not on the screen any more.
  void _addHighlight(String sectionId, int start, int end, String excerpt) {
    unawaited(
      ref
          .read(libraryProvider.notifier)
          .addHighlight(
            target: widget.entity.ref,
            sectionId: sectionId,
            start: start,
            end: end,
            excerpt: excerpt,
          ),
    );
  }

  void _removeHighlight(String highlightId) {
    unawaited(ref.read(libraryProvider.notifier).removeHighlight(highlightId));
  }

  void _recordPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    unawaited(
      ref
          .read(libraryProvider.notifier)
          .recordPosition(
            target: widget.entity.ref,
            scrollOffset: _scrollController.offset,
          ),
    );
  }

  @override
  void dispose() {
    _flushPosition();
    _positionTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Makes a pending position write now, on the way out.
  ///
  /// Leaving is the moment the position matters most, and it was the one moment
  /// it was thrown away: `dispose` cancelled the pending write without making
  /// it, so a reader who scrolled and went straight back had the article reopen
  /// at the top — or at where they had been two sessions before.
  ///
  /// It reads neither `mounted` nor the controller, because by here the state
  /// is unmounted and the scroll view detached. The offset was taken while both
  /// were alive; the notifier was taken in [initState] and belongs to the root
  /// scope, which outlives this screen.
  ///
  /// The write itself waits a microtask. Riverpod refuses a change made inside
  /// a life-cycle method — two widgets watching the same provider could come
  /// out of one build holding different states — so this leaves the life-cycle
  /// first and writes immediately after, which is still long before anything
  /// could read it.
  void _flushPosition() {
    if (!(_positionTimer?.isActive ?? false)) return;
    _positionTimer?.cancel();
    _positionTimer = null;
    final offset = _pendingOffset;
    if (offset == null) return;

    final library = _library;
    final target = widget.entity.ref;
    scheduleMicrotask(() async {
      try {
        await library.recordPosition(target: target, scrollOffset: offset);
      } on Object catch (error) {
        // The scope this belongs to can be gone by now — at shutdown, or in a
        // test that tears the tree down whole. Losing a scroll position on the
        // way out of the app is not worth an error the reader would see.
        debugPrint('Could not record where the reader had got to: $error');
      }
    });
  }

  KnowledgeEntity get entity => widget.entity;
  KnowledgeBase get corpus => widget.corpus;
  AppLanguage get language => widget.language;
  ContentDepth get depth => widget.depth;
  ValueChanged<ContentDepth> get onDepthChanged => widget.onDepthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final showCompactTitle = _showCompactTitle;

    final semantic = context.semanticColors;

    return Scaffold(
      // Reading gets its own surface, a shade apart from the rest of the app,
      // so that opening an article feels like arriving somewhere quieter. The
      backgroundColor: semantic.readingSurface,
      // The article keeps the canvas, at a quarter strength. The rule that
      // decoration under long-form text is noise is right, and a wash this
      // faint is not decoration — it is what stops the one screen a reader
      // spends most of their time on from being the one screen that looks
      // like a different product.
      body: LamplightBackdrop(
        intensity: 0.25,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              // The bar takes the masthead's first stop rather than the reading
              // surface, so the top of the screen is one block of colour instead
              // of a beige strip with a coloured panel below it. It keeps the
              // colour when the reader scrolls into the prose, which is what
              // says which entry they are still inside.
              backgroundColor: AppGradients.forSeed(entity.name.en)
                  .colors
                  .first,
              foregroundColor: AppGradients.onGradient,
              // Named rather than left to `AppBar`: an article reached from a
              // shared link is the first entry in the history, so the implied
              // back arrow is absent and this screen carries no navigation bar
              // to fall back on.
              leading: const UpButton(color: AppGradients.onGradient),
              // The title's colour has to be named here as well as on the bar.
              // `foregroundColor` tints the icons, but the title takes
              // `titleTextStyle`, and the theme's carries an explicit
              // `onSurface` — dark ink in light mode, so the entry's name was
              // near-black on its own coloured masthead.
              titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                color: AppGradients.onGradient,
              ),
              // The title only appears once the reader has scrolled past the
              // real one, so the screen opens with a single heading rather than
              // the same words twice.
              title: AnimatedOpacity(
                opacity: showCompactTitle ? 1 : 0,
                duration: Motion.duration(context, MotionTokens.quick),
                child: Text(entity.name.resolve(language)),
              ),
              actions: <Widget>[
                _BookmarkButton(target: entity.ref),
                const SizedBox(width: Spacing.xs),
              ],
            ),
            // Full-bleed, and therefore its own sliver rather than a child of
            // the reading column: an article's masthead runs edge to edge while
            // its prose keeps the measure.
            SliverToBoxAdapter(
              child: _Masthead(
                entity: entity,
                language: language,
                // A reference entry for the Republic that never says Plato wrote
                // it is not a reference entry. The author is resolved here
                // rather than inside the masthead so the masthead stays free of
                // the corpus.
                author: switch (entity) {
                  final Work work => corpus.philosopher(work.authorId),
                  _ => null,
                },
              ),
            ),
            SliverToBoxAdapter(
              child: ReadingColumn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    Spacing.lg,
                    Spacing.lg,
                    Spacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Header(
                        entity: entity,
                        taxonomy: corpus.taxonomy,
                        language: language,
                      ),
                      // Only as much room as there is something to put in it.
                      // Every school in the corpus has no article, and the page
                      // reserved the space anyway — a hole between the tags and
                      // the first real section that read as a rendering fault.
                      if (!entity.article.isEmpty) ...<Widget>[
                        const SizedBox(height: Spacing.xl),
                        if (entity.article.hasMoreBeyond(ContentDepth.quick) ||
                            depth != ContentDepth.quick)
                          _DepthSelector(
                            article: entity.article,
                            depth: depth,
                            language: language,
                            onChanged: onDepthChanged,
                          ),
                        const SizedBox(height: Spacing.lg),
                      ],
                      // Changing depth replaces the whole article. Without the
                      // cross-fade the page snaps to a new length while the
                      // reader's eye is still on the old text.
                      SmoothSwitcher(
                        child: ArticleView(
                          key: ValueKey<String>('${entity.id}-${depth.id}'),
                          article: entity.article,
                          depth: depth,
                          language: language,
                          resolveSource: corpus.source,
                          highlights: ref
                              .watch(libraryProvider)
                              .highlightsFor(entity.ref),
                          // A reader who meets a word they do not know should
                          // not have to leave the sentence to find out what it
                          // means.
                          glossary: corpus.glossary,
                          onTermTapped: (term) =>
                              showGlossaryTerm(context, term, language),
                          onHighlight: _addHighlight,
                          onRemoveHighlight: _removeHighlight,
                        ),
                      ),
                      ..._kindSpecificSections(context),
                      _ConnectionsSection(
                        entity: entity,
                        corpus: corpus,
                        language: language,
                      ),
                      _NotesSection(target: entity.ref),
                      if (entity.citations.isNotEmpty) ...<Widget>[
                        const SizedBox(height: Spacing.xl),
                        SectionHeader(title: l10n.sectionSources),
                        CitationList(
                          citations: entity.citations,
                          language: language,
                          resolveSource: corpus.source,
                        ),
                      ],
                      const SizedBox(height: Spacing.xl),
                      _ReadMarkFooter(target: entity.ref),
                      const SizedBox(height: Spacing.xl),
                      Text(
                        _provenanceNote(language),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _provenanceNote(AppLanguage language) => language == AppLanguage.fa
      ? 'مدخل‌ها بر پایهٔ متون اصلی و منابع دانشگاهی نوشته شده‌اند. اختلاف‌های '
            'پژوهشی حذف نمی‌شوند، بلکه نشان داده می‌شوند.'
      : 'Entries are written from primary texts and academic sources. '
            'Scholarly disagreement is shown, not smoothed away.';

  List<Widget> _kindSpecificSections(BuildContext context) => <Widget>[
    // Before whatever the kind adds, because it is the same question for all
    // four of them and a reader who has just finished the summary is at the
    // point of asking it.
    ..._whenSection(context),
    ...switch (entity) {
      final Philosopher philosopher => _philosopherSections(
        context,
        philosopher,
      ),
      final Concept concept => _conceptSections(context, concept),
      final Work work => _workSections(context, work),
      final School school => _schoolSections(context, school),
      final Argument argument => _argumentSections(context, argument),
      _ => const <Widget>[],
    },
  ];

  /// The timeline band, and the caption that says what it is.
  ///
  /// Every kind gets one, from a different field: a philosopher's life, a
  /// work's composition, a school's period, and for a concept the span of the
  /// philosophers filed under it — which is the honest way to date an idea,
  /// since ideas do not have birthdays but the people arguing them do.
  ///
  /// Returns nothing rather than an empty band when the dates are missing, so
  /// a future entry without them degrades to the layout that existed before
  /// this was added.
  List<Widget> _whenSection(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = entity.name.resolve(language);

    final (
      HistoricalRange? span,
      List<int> others,
      String Function(String) caption,
    ) = switch (entity) {
      // A floruit gets a caption of its own. Read out under the band, the
      // ordinary one would say a figure "lived" through years the record only
      // says they were active in, which is the claim the floruit exists to
      // avoid making.
      final Philosopher philosopher => (
        _rangeOfLife(philosopher.life),
        _anchors(corpus.philosophers.map((p) => p.life.sortAnchor)),
        philosopher.life.birth == null && philosopher.life.death == null
            ? (dates) => l10n.timelinePhilosopherFloruit(name, dates)
            : (dates) => l10n.timelinePhilosopher(name, dates),
      ),
      final Work work => (
        work.composed,
        _anchors(corpus.works.map((w) => w.composed?.start ?? w.composed?.end)),
        l10n.timelineWork,
      ),
      final School school => (
        school.period,
        _anchors(corpus.schools.map((s) => s.period?.start ?? s.period?.end)),
        l10n.timelineSchool,
      ),
      final Concept concept => (
        _spanOfPhilosophers(concept.philosopherIds),
        _anchors(corpus.philosophers.map((p) => p.life.sortAnchor)),
        l10n.timelineConcept,
      ),
      _ => (null, const <int>[], (dates) => dates),
    };

    if (span == null) return const <Widget>[];
    final dates = AppDates.range(span, language, l10n);
    if (dates == null) return const <Widget>[];

    return <Widget>[
      _CardSection(
        title: l10n.sectionWhen,
        children: <Widget>[
          TimelineBand(
            span: span,
            others: others,
            caption: caption(dates),
            startLabel: _edgeLabel(others, span, l10n, lowest: true),
            endLabel: _edgeLabel(others, span, l10n, lowest: false),
          ),
        ],
      ),
    ];
  }

  /// A life as a range, preferring attested dates and falling back to the
  /// floruit for the many ancient figures who have only that.
  static HistoricalRange? _rangeOfLife(LifeSpan life) {
    if (life.birth != null || life.death != null) {
      return HistoricalRange(start: life.birth, end: life.death);
    }
    return life.floruit;
  }

  /// The span from the earliest to the latest of a set of philosophers.
  HistoricalRange? _spanOfPhilosophers(List<String> ids) {
    final years = <HistoricalYear>[
      for (final id in ids) ?corpus.philosopher(id)?.life.sortAnchor,
    ];
    if (years.isEmpty) return null;
    years.sort();
    return HistoricalRange(start: years.first, end: years.last);
  }

  static List<int> _anchors(Iterable<HistoricalYear?> years) => <int>[
    for (final year in years)
      if (year != null) year.year,
  ];

  /// The year at one end of the band, formatted for the reader.
  String? _edgeLabel(
    List<int> others,
    HistoricalRange span,
    AppL10n l10n, {
    required bool lowest,
  }) {
    final years = <int>[
      ...others,
      if (span.start != null) span.start!.year,
      if (span.end != null) span.end!.year,
    ];
    if (years.isEmpty) return null;
    // The extremes of the data, not the band's drawn bounds. The band is
    // padded outward so the earliest entry is not painted half off the edge,
    // and labelling that padding printed "2574 BCE" and "2131 CE" — two years
    // in which nothing happened and to which no entry is dated. A label on an
    // axis is a claim about the data, so it has to name a year the data
    // actually reaches.
    years.sort();
    return AppDates.year(
      HistoricalYear(lowest ? years.first : years.last),
      language,
      l10n,
    );
  }

  List<Widget> _philosopherSections(
    BuildContext context,
    Philosopher philosopher,
  ) {
    final l10n = AppL10n.of(context);
    final works = corpus.worksBy(philosopher.id);
    final quotes = corpus.quotesBy(philosopher.id);
    final arguments = corpus.argumentsBy(philosopher.id);
    final concepts = philosopher.conceptIds
        .map(corpus.concept)
        .whereType<Concept>()
        .toList();
    // Schools were parsed from the corpus and then dropped on the floor: a
    // philosopher's page never said which traditions of thought they belong
    // to, though the data was sitting on the record. For several entries it
    // is the only outbound link they have.
    final schools = philosopher.schoolIds
        .map(corpus.school)
        .whereType<School>()
        .toList();

    return <Widget>[
      if (schools.isNotEmpty)
        _CardSection(
          title: l10n.sectionSchools,
          children: <Widget>[
            for (final school in schools)
              EntityCard(
                title: school.name.resolve(language),
                summary: school.oneLine.resolve(language),
                onTap: () => context.push(school.ref.route),
              ),
          ],
        ),
      if (concepts.isNotEmpty)
        _CardSection(
          title: l10n.sectionConcepts,
          children: <Widget>[
            for (final concept in concepts)
              EntityCard(
                title: concept.name.resolve(language),
                summary: concept.oneLine.resolve(language),
                onTap: () => context.push(concept.ref.route),
              ),
          ],
        ),
      // The works section appears whenever there is something to say about
      // the works — which includes saying that there are none. Omitting it
      // silently made Socrates and Hypatia look like entries somebody had not
      // finished, when in fact the absence is the fact.
      if (works.isNotEmpty || philosopher.writings != Writings.extant)
        _CardSection(
          title: l10n.sectionWorks,
          children: <Widget>[
            if (philosopher.writings != Writings.extant)
              _WritingsNote(
                text: philosopher.writings == Writings.none
                    ? l10n.writingsNone
                    : l10n.writingsFragments,
              ),
            for (final work in works)
              EntityCard(
                title: work.name.resolve(language),
                summary: work.oneLine.resolve(language),
                meta: AppDates.range(work.composed, language, l10n),
                onTap: () => context.push(work.ref.route),
              ),
          ],
        ),
      if (arguments.isNotEmpty)
        _CardSection(
          title: l10n.sectionArguments,
          children: <Widget>[
            for (final argument in arguments)
              ArgumentPanel(
                argument: argument,
                language: language,
                onOpen: () => context.push(argument.ref.route),
                opposedByReader: !argument.proponentIds.contains(
                  philosopher.id,
                ),
                raisedByName: (id) =>
                    corpus.philosopher(id)?.name.resolve(language),
              ),
          ],
        ),
      if (quotes.isNotEmpty)
        _CardSection(
          title: l10n.sectionQuotes,
          children: <Widget>[
            for (final quote in quotes)
              QuoteCard(
                quote: quote,
                language: language,
                speakerName: philosopher.name.resolve(language),
                resolveSource: corpus.source,
              ),
          ],
        ),
    ];
  }

  List<Widget> _conceptSections(BuildContext context, Concept concept) {
    final l10n = AppL10n.of(context);
    final related = concept.relatedConceptIds
        .map(corpus.concept)
        .whereType<Concept>()
        .toList();
    final philosophers = concept.philosopherIds
        .map(corpus.philosopher)
        .whereType<Philosopher>()
        .toList();
    final works = concept.workIds.map(corpus.work).whereType<Work>().toList();
    final opposes = concept.opposingConceptIds
        .map(corpus.concept)
        .whereType<Concept>()
        .toList();

    return <Widget>[
      if (concept.examples.isNotEmpty)
        _ProseSection(
          title: l10n.sectionExamples,
          items: concept.examples,
          language: language,
        ),
      if (concept.counterexamples.isNotEmpty)
        _ProseSection(
          title: l10n.sectionCounterexamples,
          items: concept.counterexamples,
          language: language,
        ),
      // "Related ideas", not "Key ideas": the reader is already on an idea,
      // so a heading calling these the key ones reads as a claim about the
      // concept above rather than a list of its neighbours.
      if (related.isNotEmpty)
        _CardSection(
          title: l10n.sectionRelatedIdeas,
          children: <Widget>[
            for (final other in related)
              EntityCard(
                title: other.name.resolve(language),
                summary: other.oneLine.resolve(language),
                onTap: () => context.push(other.ref.route),
              ),
          ],
        ),
      // An idea has no birthday and no address; the people arguing it are how a
      // reader gets anywhere from here. Every concept names at least one, and
      // forty-one of them had no examples, no counterexamples and no
      // neighbours — so without this the page was prose and then nothing.
      if (philosophers.isNotEmpty)
        _CardSection(
          title: l10n.sectionPhilosophers,
          children: <Widget>[
            for (final philosopher in philosophers)
              EntityCard(
                title: philosopher.name.resolve(language),
                summary: philosopher.oneLine.resolve(language),
                meta: AppDates.lifeSpan(philosopher.life, language, l10n),
                onTap: () => context.push(philosopher.ref.route),
              ),
          ],
        ),
      if (works.isNotEmpty)
        _CardSection(
          title: l10n.sectionWorks,
          children: <Widget>[
            for (final work in works)
              EntityCard(
                title: work.name.resolve(language),
                summary: work.oneLine.resolve(language),
                meta: AppDates.range(work.composed, language, l10n),
                onTap: () => context.push(work.ref.route),
              ),
          ],
        ),
      ..._opposesSection(context, opposes),
    ];
  }

  /// What this entry is set against.
  ///
  /// Kept apart from Connections because the two carry different things. A
  /// relation is authored: it names a dispute and explains it in a sentence.
  /// These are the bare oppositions recorded on the entry itself, and thirteen
  /// of the fifteen in the corpus have no relation to go with them — so before
  /// this they appeared nowhere, and a reader on Rationalism was never told
  /// that the corpus files it against Empiricism.
  List<Widget> _opposesSection(
    BuildContext context,
    List<KnowledgeEntity> opposed,
  ) {
    if (opposed.isEmpty) return const <Widget>[];
    return <Widget>[
      _CardSection(
        title: AppL10n.of(context).sectionOpposes,
        children: <Widget>[
          for (final other in opposed)
            EntityCard(
              title: other.name.resolve(language),
              summary: other.oneLine.resolve(language),
              onTap: () => context.push(other.ref.route),
            ),
        ],
      ),
    ];
  }

  List<Widget> _workSections(BuildContext context, Work work) {
    final l10n = AppL10n.of(context);
    final divisions = work.allDivisions.toList();
    final concepts = work.conceptIds
        .map(corpus.concept)
        .whereType<Concept>()
        .toList();
    final editions = work.editionSourceIds
        .map(corpus.source)
        .whereType<Source>()
        .toList();
    final arguments = corpus.argumentsIn(work.id);

    return <Widget>[
      if (divisions.isNotEmpty)
        _CardSection(
          title: l10n.sectionOverview,
          children: <Widget>[
            for (final division in divisions)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        joinIsolated(
                          <String?>[
                            division.title.resolve(language),
                            division.locator,
                          ].whereType<String>(),
                          ' · ',
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (division.summary != null) ...<Widget>[
                        const SizedBox(height: Spacing.xs),
                        Text(
                          division.summary!.resolve(language),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      if (concepts.isNotEmpty)
        _CardSection(
          title: l10n.sectionConcepts,
          children: <Widget>[
            for (final concept in concepts)
              EntityCard(
                title: concept.name.resolve(language),
                summary: concept.oneLine.resolve(language),
                onTap: () => context.push(concept.ref.route),
              ),
          ],
        ),
      if (arguments.isNotEmpty)
        _CardSection(
          title: l10n.sectionArguments,
          children: <Widget>[
            for (final argument in arguments)
              ArgumentPanel(
                argument: argument,
                language: language,
                onOpen: () => context.push(argument.ref.route),
                raisedByName: (id) =>
                    corpus.philosopher(id)?.name.resolve(language),
              ),
          ],
        ),
      // Which edition or translation to read is one of the questions a reader
      // actually brings to a reference work, and for a text in a language they
      // do not have it is the only question that matters. The data has been
      // loaded since the corpus was first written and was never shown.
      if (editions.isNotEmpty) ...<Widget>[
        const SizedBox(height: Spacing.xl),
        SectionHeader(title: l10n.sectionEditions),
        for (final edition in editions)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: SourceLine(source: edition, language: language),
          ),
      ],
    ];
  }

  /// The argument's own page.
  ///
  /// The prose above it is the article every entity has. What is added here is
  /// the structure — premises, conclusion, the assumptions it needs but does
  /// not state, and the objections aimed at named steps — and the people and
  /// books it connects to. Inline on a philosopher's entry the same panel is a
  /// summary with a link here; this is where the reader arrives.
  List<Widget> _argumentSections(BuildContext context, Argument argument) {
    final l10n = AppL10n.of(context);
    final proponents = argument.proponentIds
        .map(corpus.philosopher)
        .whereType<Philosopher>()
        .toList();
    final opponents = argument.opponentIds
        .map(corpus.philosopher)
        .whereType<Philosopher>()
        .toList();
    final works = argument.workIds.map(corpus.work).whereType<Work>().toList();
    final concepts = argument.conceptIds
        .map(corpus.concept)
        .whereType<Concept>()
        .toList();

    return <Widget>[
      ReadingColumn(
        child: ArgumentPanel(
          argument: argument,
          language: language,
          raisedByName: (id) => corpus.philosopher(id)?.name.resolve(language),
        ),
      ),
      if (proponents.isNotEmpty)
        _CardSection(
          title: l10n.sectionArguedBy,
          children: <Widget>[
            for (final philosopher in proponents)
              EntityCard(
                title: philosopher.name.resolve(language),
                summary: philosopher.oneLine.resolve(language),
                onTap: () => context.push(philosopher.ref.route),
              ),
          ],
        ),
      if (opponents.isNotEmpty)
        _CardSection(
          title: l10n.sectionArguedAgainstBy,
          children: <Widget>[
            for (final philosopher in opponents)
              EntityCard(
                title: philosopher.name.resolve(language),
                summary: philosopher.oneLine.resolve(language),
                onTap: () => context.push(philosopher.ref.route),
              ),
          ],
        ),
      if (works.isNotEmpty)
        _CardSection(
          title: l10n.sectionWhereItAppears,
          children: <Widget>[
            for (final work in works)
              EntityCard(
                title: work.name.resolve(language),
                summary: work.oneLine.resolve(language),
                onTap: () => context.push(work.ref.route),
              ),
          ],
        ),
      if (concepts.isNotEmpty)
        _CardSection(
          title: l10n.sectionConcepts,
          children: <Widget>[
            for (final concept in concepts)
              EntityCard(
                title: concept.name.resolve(language),
                summary: concept.oneLine.resolve(language),
                onTap: () => context.push(concept.ref.route),
              ),
          ],
        ),
    ];
  }

  List<Widget> _schoolSections(BuildContext context, School school) {
    final l10n = AppL10n.of(context);
    final members = school.memberIds
        .map(corpus.philosopher)
        .whereType<Philosopher>()
        .toList();

    final concepts = school.conceptIds
        .map(corpus.concept)
        .whereType<Concept>()
        .toList();
    final opposes = school.opposedSchoolIds
        .map(corpus.school)
        .whereType<School>()
        .toList();

    return <Widget>[
      if (school.centralClaims.isNotEmpty)
        _ProseSection(
          title: l10n.sectionCentralClaims,
          items: school.centralClaims,
          language: language,
        ),
      // The ideas before the people. A school is an argument first, and the
      // heading over the philosophers used to say "Key ideas" while this
      // section — the one that heading promises — was never built at all.
      if (concepts.isNotEmpty)
        _CardSection(
          title: l10n.sectionConcepts,
          children: <Widget>[
            for (final concept in concepts)
              EntityCard(
                title: concept.name.resolve(language),
                summary: concept.oneLine.resolve(language),
                onTap: () => context.push(concept.ref.route),
              ),
          ],
        ),
      if (members.isNotEmpty)
        _CardSection(
          title: l10n.sectionPhilosophers,
          children: <Widget>[
            for (final member in members)
              EntityCard(
                title: member.name.resolve(language),
                summary: member.oneLine.resolve(language),
                meta: AppDates.lifeSpan(
                  member.life,
                  language,
                  AppL10n.of(context),
                ),
                onTap: () => context.push(member.ref.route),
              ),
          ],
        ),
      ..._opposesSection(context, opposes),
    ];
  }
}

/// The classification chips, under the masthead.
///
/// The name, the dates and the summary used to live here too. They moved to
/// [_Masthead] when the article got a coloured head, and what is left is the
/// part that belongs on the reading surface: the tags a reader uses to leave.
class _Header extends StatelessWidget {
  const _Header({
    required this.entity,
    required this.taxonomy,
    required this.language,
  });

  final KnowledgeEntity entity;
  final Taxonomy taxonomy;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => EntranceAnimation(
    distance: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (entity.branches.isNotEmpty || entity.traditions.isNotEmpty)
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: <Widget>[
              // The chips are the only route out of an article that does not
              // depend on the entry having been given cross-references, and
              // forty-eight philosophers had none — from those pages a reader
              // could go nowhere but back. They open Explore filtered to the
              // term they name.
              for (final tradition in entity.traditions)
                TagChip(
                  label: taxonomy.nameOf(tradition).resolve(language),
                  emphasised: true,
                  // `go`, not `push`: Explore is a tab in the shell, and
                  // pushing another branch's route onto this branch's
                  // navigator duplicates its key and throws.
                  onTap: () => context.go(
                    '${AppRouter.explore}?axis=tradition&term=$tradition',
                  ),
                ),
              for (final branch in entity.branches)
                TagChip(
                  label: taxonomy.nameOf(branch).resolve(language),
                  onTap: () => context.go(
                    '${AppRouter.explore}?axis=branch&term=$branch',
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

/// Lets the reader move between depths, and says plainly when there is no more.
/// Names the author of a work, and goes to them.
///
/// Set quietly, beneath the title: on a work's page the title is the subject
/// and the author is context, which is the opposite of how a philosopher's page
/// is arranged.
class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.author, required this.language});

  final Philosopher author;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final name = author.name.resolve(language);

    return InkWell(
      onTap: () => context.push(author.ref.route),
      borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
        child: Text(
          l10n.workBy(name),
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppGradients.onGradient,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: AppGradients.onGradientMuted,
          ),
        ),
      ),
    );
  }
}

class _DepthSelector extends StatelessWidget {
  const _DepthSelector({
    required this.article,
    required this.depth,
    required this.language,
    required this.onChanged,
  });

  final Article article;
  final ContentDepth depth;
  final AppLanguage language;
  final ValueChanged<ContentDepth> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    // Only levels that change what is on the page. The Daodejing offered
    // "Quick" and "Standard" while having a single standard section, so
    // choosing Quick asked for a level that did not exist — and the article
    // rendered blank. Offering a control that cannot do anything is worse than
    // offering none.
    final deepest = article.deepestAuthoredDepth;
    final shallowest = article.shallowestAuthoredDepth;
    final available = ContentDepth.values
        .where(
          (candidate) =>
              candidate.order >= shallowest.order &&
              candidate.order <= deepest.order,
        )
        .toList();

    if (available.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.depthSelectorLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        GlowSegments<ContentDepth>(
          segments: <GlowSegment<ContentDepth>>[
            for (final candidate in available)
              GlowSegment<ContentDepth>(
                value: candidate,
                label: TaxonomyLabels.depth(candidate).resolve(language),
              ),
          ],
          selected: depth,
          onChanged: onChanged,
        ),
        if (!article.hasMoreBeyond(depth)) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.noDeeperContent,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The knowledge-graph connections for an entity, read from its own side.
class _ConnectionsSection extends StatelessWidget {
  const _ConnectionsSection({
    required this.entity,
    required this.corpus,
    required this.language,
  });

  final KnowledgeEntity entity;
  final KnowledgeBase corpus;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final relations = corpus.relationsFor(entity.ref);
    if (relations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Spacing.xl),
        SectionHeader(title: l10n.sectionConnections),
        for (final relation in relations)
          Builder(
            builder: (context) {
              final other = corpus.resolve(relation.object);
              final label = TaxonomyLabels.relation(relation).resolve(language);
              // Named through the corpus rather than through `other`: a
              // relation can point at a quotation, an argument or a source,
              // and those have no page — `other` is null for all three. Using
              // it for the name as well as for the link printed the identifier
              // where the name belongs, so Kant's page read "criticised
              // contingency-argument".
              final name =
                  corpus.nameOf(relation.object)?.resolve(language) ??
                  relation.object.id;
              final note = relation.note;

              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: InkWell(
                  onTap: other == null
                      ? null
                      : () => context.push(relation.object.route),
                  borderRadius: Radii.cardRadius,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: Spacing.xs,
                          runSpacing: Spacing.xxs,
                          children: <Widget>[
                            Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: '$label ',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  TextSpan(
                                    text: name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            RelationConfidenceBadge(
                              confidence: relation.confidence,
                              language: language,
                            ),
                          ],
                        ),
                        if (note != null) ...<Widget>[
                          const SizedBox(height: Spacing.xxs),
                          Text(
                            note.resolve(language),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// The note that stands where a philosopher's books would be.
///
/// Deliberately not an [EntityCard]: it is not a thing to open, and giving it
/// the same shape as the works beside it would invite a tap that goes nowhere.
/// A quieter surface with a mark beside the text reads as an editorial note,
/// which is what it is.
class _WritingsNote extends StatelessWidget {
  const _WritingsNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GlassPanel(
      padding: const EdgeInsets.all(Spacing.md),
      borderStrength: 0.6,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.history_edu_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SizedBox(height: Spacing.xl),
      SectionHeader(title: title),
      // Every child of a section is a full-width block, and one of them was
      // not getting to be. A `Column` aligned to the start hands its children
      // loose constraints, so anything that sizes to its own content keeps its
      // own width — most of these are `EntityCard`, which fills, but the work
      // overview used a bare `Card`, and its two entries came out different
      // widths because one summary was shorter than the other. Two cards in a
      // column with different right edges look like a rendering fault.
      //
      // Stated here rather than at that one call site so the next bare card
      // added to a section does not repeat it. The header is deliberately left
      // out: it is a row that may carry a trailing control, and stretching it
      // would move that control.
      for (final child in children) ...<Widget>[
        SizedBox(width: double.infinity, child: child),
        const SizedBox(height: Spacing.md),
      ],
    ],
  );
}

class _ProseSection extends StatelessWidget {
  const _ProseSection({
    required this.title,
    required this.items,
    required this.language,
  });

  final String title;
  final List<LocalizedText> items;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Spacing.xl),
        SectionHeader(title: title),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    item.resolve(language),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Saves or unsaves the article.
///
/// The icon is the state: filled when saved, outlined when not. There is no
/// confirmation, because the action is instant and reversible by pressing the
/// same button again — a dialog here would be ceremony over a bookmark.
class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.target});

  final EntityRef target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final isSaved = ref.watch(isBookmarkedProvider(target));

    return IconButton(
      tooltip: isSaved ? l10n.bookmarkRemove : l10n.bookmarkAdd,
      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
      // Both states are measured against the masthead's colour, not the page's
      // — the button sits in an app bar that carries the entry's gradient, and
      // the theme's secondary is a light-mode accent that vanishes on it.
      color: isSaved ? AppGradients.onGradient : AppGradients.onGradientMuted,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final saved = await ref
            .read(libraryProvider.notifier)
            .toggleBookmark(target);
        if (!saved) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
        }
      },
    );
  }
}

/// The tick at the foot of an article: the reader saying they have read it.
///
/// ## Why it is here and not at the top
///
/// The claim is that the article has been read, so the only place it can
/// honestly be made is after the article. A control at the top would be a
/// promise; this is a report.
///
/// It is also the one thing on the page that feeds the quiz — questions are
/// only asked about entries a reader has marked — so it says so rather than
/// leaving the reader to discover the connection by accident.
class _ReadMarkFooter extends ConsumerWidget {
  const _ReadMarkFooter({required this.target});

  final EntityRef target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final hasRead = ref.watch(hasReadProvider(target));

    return PressableSurface(
      onTap: () =>
          unawaited(ref.read(libraryProvider.notifier).toggleRead(target)),
      borderRadius: Radii.surfaceRadius,
      child: Semantics(
        checked: hasRead,
        label: l10n.articleMarkRead,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: Radii.surfaceRadius,
            // Lit once ticked, so a reader scrolling back through entries can
            // see at the foot of each which ones they have finished.
            color: hasRead
                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            border: Border.all(
              color: hasRead
                  ? theme.colorScheme.primary.withValues(alpha: 0.45)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: Motion.duration(context, MotionTokens.quick),
                curve: MotionTokens.standard,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasRead
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: hasRead
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                child: hasRead
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                // `ExcludeSemantics` because the `Semantics` above already
                // names the control; without it a screen reader reads the
                // label twice, once as the checkbox and once as loose text.
                child: ExcludeSemantics(
                  child: Text(
                    hasRead ? l10n.articleMarkedRead : l10n.articleMarkRead,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: hasRead
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reader's notes on this article, and the way to add one.
class _NotesSection extends ConsumerWidget {
  const _NotesSection({required this.target});

  final EntityRef target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final notes = ref.watch(notesForProvider(target));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Spacing.xl),
        SectionHeader(
          title: l10n.notesTitle,
          trailing: TextButton.icon(
            onPressed: () => _compose(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.noteAdd),
          ),
        ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: Radii.cardRadius,
                border: BorderDirectional(
                  start: BorderSide(color: theme.colorScheme.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(note.body, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: Spacing.sm),
                  Row(
                    children: <Widget>[
                      if (note.isEdited)
                        Text(
                          l10n.noteEdited,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => ref
                            .read(libraryProvider.notifier)
                            .deleteNote(note.id),
                        child: Text(l10n.noteDelete),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);

    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const _NoteComposer(),
    );

    if (body == null || body.trim().isEmpty) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final note = await ref
        .read(libraryProvider.notifier)
        .addNote(target: target, body: body);
    if (note == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }
}

/// The note-writing sheet.
///
/// It owns its own text controller. Disposing a controller in the caller as soon
/// as the sheet returns throws: the sheet is still running its closing
/// animation, and the `TextField` inside it rebuilds at least once more against
/// a controller that no longer exists.
class _NoteComposer extends StatefulWidget {
  const _NoteComposer();

  @override
  State<_NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<_NoteComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Padding(
      // Lifted above the keyboard, so the reader can see what they type.
      padding: EdgeInsets.only(
        left: Spacing.lg,
        right: Spacing.lg,
        top: Spacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.noteAdd, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.noteHint),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: Spacing.sm),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_controller.text),
                child: Text(l10n.noteSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The article's coloured head: dates, name, original script, summary.
///
/// ## Why this is coloured when the prose is not
///
/// The rule the reading surface follows — that decoration under long-form text
/// is noise — is right, and it is about the prose. It left the article opening
/// on a page indistinguishable from every other article in the product, and a
/// reference work of two hundred entries needs the reader to feel they have
/// arrived somewhere in particular.
///
/// The gradient is seeded from the entity's name, which is the same seed the
/// coloured initial on its card uses. So a reader who taps a slate-blue chip
/// in a list lands on a slate-blue page: the colour carries no meaning, but it
/// is consistent, and consistency is what makes it recognition rather than
/// decoration.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.entity, required this.language, this.author});

  final KnowledgeEntity entity;
  final AppLanguage language;

  /// The author, when the entity is a work whose author is in the corpus.
  final Philosopher? author;

  /// The direction a name in its original script should be laid out in.
  ///
  /// `ابن سينا` must run right-to-left even when the interface is English, and
  /// `Πλάτων` must run left-to-right even when the interface is Persian.
  TextDirection _scriptDirection(String text) =>
      TextNormalizer.containsArabicScript(text)
      ? TextDirection.rtl
      : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final gradient = AppGradients.forSeed(entity.name.en);

    final native = switch (entity) {
      final Philosopher philosopher => philosopher.nativeName,
      final Concept concept => concept.nativeTerm,
      final Work work => work.originalTitle,
      final School school => school.nativeName,
      _ => null,
    };

    // Thirteen philosophers carry a birthplace and eleven a place of death,
    // and none of them was shown anywhere in the app. It belongs here rather
    // than under the timeline: a place is not a date, and a heading that says
    // "When" over a line that says "Born in Athens" is the same category
    // mistake as a heading that says "Key ideas" over a list of people.
    final place = switch (entity) {
      final Philosopher philosopher => _placeLine(l10n, language, philosopher),
      _ => null,
    };

    final meta = switch (entity) {
      final Philosopher philosopher => AppDates.lifeSpan(
        philosopher.life,
        language,
        l10n,
      ),
      final Work work => AppDates.range(work.composed, language, l10n),
      final School school => AppDates.range(school.period, language, l10n),
      _ => null,
    };

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: GradientSheen(
        alignment: const Alignment(0.9, -1),
        child: SafeArea(
          top: false,
          bottom: false,
          child: ReadingColumn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                Spacing.xl,
              ),
              child: EntranceAnimation(
                distance: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Dates lead, so the reader is placed in history before
                    // they are given a name.
                    if (meta != null) ...<Widget>[
                      Text(
                        meta,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppGradients.onGradientMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                    Semantics(
                      header: true,
                      child: Text(
                        entity.name.resolve(language),
                        style: theme.textTheme.displaySmall?.copyWith(
                          height: 1.08,
                          color: AppGradients.onGradient,
                        ),
                      ),
                    ),
                    if (native != null) ...<Widget>[
                      const SizedBox(height: Spacing.xs),
                      // The original script is set large and quiet rather than
                      // as a footnote. For a great many readers it is the name
                      // they know, and shrinking it to metadata quietly says
                      // whose language is primary.
                      Text(
                        native,
                        textDirection: _scriptDirection(native),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppGradients.onGradientMuted,
                          fontWeight: FontWeight.w400,
                          // The entity's own tradition chooses which CJK face
                          // answers first. Without this every Japanese and
                          // Korean name was drawn by the Chinese face, which
                          // is what bundling three of them was meant to avoid.
                          fontFamilyFallback: AppTypography.nativeNameFallbacks(
                            language,
                            entity.traditions,
                          ),
                        ),
                      ),
                    ],
                    if (author != null) ...<Widget>[
                      const SizedBox(height: Spacing.xs),
                      _AuthorLine(author: author!, language: language),
                    ],
                    if (place != null) ...<Widget>[
                      const SizedBox(height: Spacing.sm),
                      Text(
                        place,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppGradients.onGradientMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.lg),
                    Text(
                      entity.oneLine.resolve(language),
                      style: theme.textTheme.titleMedium?.copyWith(
                        height: 1.45,
                        color: AppGradients.onGradient,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a philosopher was born and died, in whichever of the four shapes the
/// record supports.
///
/// Returns null when neither place is recorded, which is most of the corpus —
/// a birthplace is a fact somebody has to have written down, and for a great
/// many of these people nobody did.
String? _placeLine(
  AppL10n l10n,
  AppLanguage language,
  Philosopher philosopher,
) {
  final birth = philosopher.birthPlace?.resolve(language);
  final death = philosopher.deathPlace?.resolve(language);
  if (birth == null && death == null) return null;
  if (birth == null) return l10n.placeDied(death!);
  if (death == null) return l10n.placeBorn(birth);
  if (birth == death) return l10n.placeLived(birth);
  return l10n.placeBornDied(birth, death);
}
