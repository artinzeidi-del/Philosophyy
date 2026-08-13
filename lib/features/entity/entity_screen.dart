import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
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

class _EntityBody extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            title: Text(entity.name.resolve(language)),
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
                    _Header(entity: entity, language: language),
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
                    ArticleView(
                      article: entity.article,
                      depth: depth,
                      language: language,
                      resolveSource: corpus.source,
                    ),
                    ..._kindSpecificSections(context),
                    _ConnectionsSection(
                      entity: entity,
                      corpus: corpus,
                      language: language,
                    ),
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
  const _Header({required this.entity, required this.language});

  final KnowledgeEntity entity;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            entity.name.resolve(language),
            style: theme.textTheme.displaySmall,
          ),
        ),
        if (native != null) ...<Widget>[
          const SizedBox(height: Spacing.xs),
          Text(
            native,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        if (meta != null) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          Text(
            meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        Text(
          entity.oneLine.resolve(language),
          style: theme.textTheme.titleLarge,
        ),
        if (entity.branches.isNotEmpty || entity.traditions.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: <Widget>[
              for (final tradition in entity.traditions)
                TagChip(
                  label: TaxonomyLabels.tradition(tradition).resolve(language),
                  emphasised: true,
                ),
              for (final branch in entity.branches)
                TagChip(label: TaxonomyLabels.branch(branch).resolve(language)),
            ],
          ),
        ],
      ],
    );
  }
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
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                            ],
                          ),
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
