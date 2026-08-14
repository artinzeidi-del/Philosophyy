import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/core/search/text_normalizer.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/concept.dart';
import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/school.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
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
          depth: _depth ?? ref.read(settingsProvider).defaultDepth,
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

  @override
  void initState() {
    super.initState();
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

    _positionTimer?.cancel();
    _positionTimer = Timer(_positionSettleDelay, _recordPosition);
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
    _positionTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
      // lamplight backdrop used on the front-of-house screens is deliberately
      // absent here: under long-form text, decoration is noise.
      backgroundColor: semantic.readingSurface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: semantic.readingSurface,
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
          SliverToBoxAdapter(
            child: ReadingColumn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.sm,
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
    );
  }

  String _provenanceNote(AppLanguage language) => language == AppLanguage.fa
      ? 'مدخل‌ها بر پایهٔ متون اصلی و منابع دانشگاهی نوشته شده‌اند. اختلاف‌های '
            'پژوهشی حذف نمی‌شوند، بلکه نشان داده می‌شوند.'
      : 'Entries are written from primary texts and academic sources. '
            'Scholarly disagreement is shown, not smoothed away.';

  List<Widget> _kindSpecificSections(BuildContext context) => switch (entity) {
    final Philosopher philosopher => _philosopherSections(context, philosopher),
    final Concept concept => _conceptSections(context, concept),
    final Work work => _workSections(context, work),
    final School school => _schoolSections(context, school),
    _ => const <Widget>[],
  };

  List<Widget> _philosopherSections(
    BuildContext context,
    Philosopher philosopher,
  ) {
    final l10n = AppL10n.of(context);
    final works = corpus.worksBy(philosopher.id);
    final quotes = corpus.quotesBy(philosopher.id);
    final concepts = philosopher.conceptIds
        .map(corpus.concept)
        .whereType<Concept>()
        .toList();

    return <Widget>[
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
      if (quotes.isNotEmpty)
        _CardSection(
          title: l10n.sectionQuotes,
          children: <Widget>[
            for (final quote in quotes)
              QuoteCard(
                quote: quote,
                language: language,
                speakerName: philosopher.name.resolve(language),
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
      if (related.isNotEmpty)
        _CardSection(
          title: l10n.sectionConcepts,
          children: <Widget>[
            for (final other in related)
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
                        <String?>[
                          division.title.resolve(language),
                          division.locator,
                        ].whereType<String>().join(' · '),
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
    ];
  }

  List<Widget> _schoolSections(BuildContext context, School school) {
    final l10n = AppL10n.of(context);
    final members = school.memberIds
        .map(corpus.philosopher)
        .whereType<Philosopher>()
        .toList();

    return <Widget>[
      if (school.centralClaims.isNotEmpty)
        _ProseSection(
          title: l10n.sectionCentralClaims,
          items: school.centralClaims,
          language: language,
        ),
      if (members.isNotEmpty)
        _CardSection(
          title: l10n.sectionConcepts,
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
    ];
  }
}

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    final native = switch (entity) {
      final Philosopher philosopher => philosopher.nativeName,
      final Concept concept => concept.nativeTerm,
      final Work work => work.originalTitle,
      final School school => school.nativeName,
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

    return EntranceAnimation(
      distance: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Dates lead, in the accent colour and letter-spaced, so the reader
          // is placed in history before they are given a name.
          if (meta != null) ...<Widget>[
            Text(
              meta,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: Spacing.sm),
          ],
          Semantics(
            header: true,
            child: Text(
              entity.name.resolve(language),
              style: theme.textTheme.displaySmall?.copyWith(height: 1.08),
            ),
          ),
          if (native != null) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            // The original script is set large and quiet rather than as a
            // footnote. For a great many readers it is the name they know, and
            // shrinking it to metadata quietly says whose language is primary.
            Text(
              native,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
              // The original script has its own direction, which is frequently
              // not the interface's.
              textDirection: _scriptDirection(native),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          const TitleRule(),
          const SizedBox(height: Spacing.lg),
          Text(
            entity.oneLine.resolve(language),
            style: theme.textTheme.titleLarge?.copyWith(height: 1.45),
          ),
          if (entity.branches.isNotEmpty || entity.traditions.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: <Widget>[
                for (final tradition in entity.traditions)
                  TagChip(
                    label: taxonomy.nameOf(tradition).resolve(language),
                    emphasised: true,
                  ),
                for (final branch in entity.branches)
                  TagChip(label: taxonomy.nameOf(branch).resolve(language)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The direction a name in its original script should be laid out in.
  ///
  /// `ابن سينا` must run right-to-left even when the interface is English, and
  /// `Πλάτων` must run left-to-right even when the interface is Persian.
  TextDirection _scriptDirection(String text) =>
      TextNormalizer.containsArabicScript(text)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

/// Lets the reader move between depths, and says plainly when there is no more.
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
    final deepest = article.deepestAuthoredDepth;
    final available = ContentDepth.values
        .where((candidate) => candidate.order <= deepest.order)
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
        SegmentedButton<ContentDepth>(
          segments: <ButtonSegment<ContentDepth>>[
            for (final candidate in available)
              ButtonSegment<ContentDepth>(
                value: candidate,
                label: Text(TaxonomyLabels.depth(candidate).resolve(language)),
              ),
          ],
          selected: <ContentDepth>{depth},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
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
              final name = other?.name.resolve(language) ?? relation.object.id;
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
      for (final child in children) ...<Widget>[
        child,
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
      color: isSaved ? Theme.of(context).colorScheme.secondary : null,
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
