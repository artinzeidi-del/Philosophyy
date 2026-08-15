import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/responsive.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/skeletons.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The home screen.
///
/// The hardest audience for a philosophy product is somebody who is curious but
/// does not yet know what they are curious about, and a wall of alphabetical
/// entries fails them completely. So the first thing on this screen is not a
/// menu but a single quotation with its context — something to react to before
/// being asked to choose anything.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corpus = ref.watch(corpusProvider);
    final language = ref.watch(activeLanguageProvider);

    return Scaffold(
      // The backdrop paints the surface, so the scaffold must not cover it.
      backgroundColor: Colors.transparent,
      body: LamplightBackdrop(
        child: corpus.when(
          loading: HomeSkeleton.new,
          error: (error, stack) => ErrorView(
            details: error.toString(),
            onRetry: () => ref.invalidate(corpusProvider),
          ),
          data: (data) => _HomeBody(corpus: data, language: language),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.corpus, required this.language});

  final KnowledgeBase corpus;
  final AppLanguage language;

  /// The quotation of the day.
  ///
  /// Chosen by the date rather than at random, so that it is the same on every
  /// device and does not change when the reader returns to the screen — a
  /// "daily" thing that changes on scroll is not daily.
  Quote? get _dailyQuote {
    final shareable = corpus.quotes
        .where((quote) => quote.isShareable)
        .toList();
    if (shareable.isEmpty) return null;
    return shareable[_dayNumber % shareable.length];
  }

  /// Entry points, one per tradition, rotated by the day.
  ///
  /// Deliberately not "the most famous": a newcomer's first screen is where a
  /// product silently declares whose philosophy counts, so this takes one from
  /// each tradition rather than the top of a canon.
  ///
  /// The rotation matters now in a way it did not at fourteen entries. Taking
  /// the first of each tradition in file order meant the same six names every
  /// day out of a hundred and ninety-one, so most of the corpus was
  /// unreachable from the screen a reader opens first. The offset is derived
  /// from the date, so it is stable within a day and does not reshuffle on
  /// scroll.
  List<Philosopher> startingPoints(int count) {
    final byTradition = <String, List<Philosopher>>{};
    for (final philosopher in corpus.philosophersChronologically) {
      final tradition = philosopher.traditions.firstOrNull ?? '';
      byTradition
          .putIfAbsent(tradition, () => <Philosopher>[])
          .add(philosopher);
    }
    final traditions = byTradition.keys.toList()..sort();
    final picks = <Philosopher>[];
    for (var i = 0; i < traditions.length && picks.length < count; i++) {
      final group =
          byTradition[traditions[(_dayNumber + i) % traditions.length]]!;
      picks.add(group[_dayNumber % group.length]);
    }
    return picks;
  }

  /// Days since the epoch, used to rotate anything that should change daily.
  static int get _dayNumber {
    final today = DateTime.now();
    return DateTime.utc(
          today.year,
          today.month,
          today.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final quote = _dailyQuote;

    // Entrance order runs top to bottom, so the eye is led down the page in
    // reading order rather than everything arriving at once.
    var step = 0;

    // The whole page used to sit inside one ReadingColumn, so a desktop window
    // showed a narrow strip of cards pinned left of centre with a third of the
    // glass empty. Prose keeps the reading measure; the cards get the content
    // measure and a grid, which is the rule the rest of the product follows
    // and which this screen had never been given.
    final columns = ResponsiveLayout.columnsFor(context);
    final entryPoints = startingPoints(columns == 1 ? 4 : columns * 2);

    return SafeArea(
      child: ContentColumn(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.gutterFor(context),
            Spacing.xxl,
            ResponsiveLayout.gutterFor(context),
            Spacing.xxxl,
          ),
          children: <Widget>[
            ReadingColumn(
              alignToStart: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  EntranceAnimation(
                    index: step++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.appName,
                          style: theme.textTheme.displayMedium?.copyWith(
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                        const TitleRule(),
                        const SizedBox(height: Spacing.md),
                        Text(
                          l10n.appTagline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.xxl),

                  if (quote != null) ...<Widget>[
                    EntranceAnimation(
                      index: step++,
                      child: SectionHeader(title: l10n.homeDailyIdea),
                    ),
                    EntranceAnimation(
                      index: step++,
                      child: QuoteCard(
                        quote: quote,
                        language: language,
                        speakerName:
                            corpus
                                .philosopher(quote.speakerId)
                                ?.name
                                .resolve(language) ??
                            quote.speakerId,
                        onTapSpeaker: () =>
                            context.push(quote.speakerRef.route),
                      ),
                    ),
                    if (quote.context != null)
                      EntranceAnimation(
                        index: step++,
                        child: Padding(
                          padding: const EdgeInsets.only(top: Spacing.md),
                          child: Text(
                            quote.context!.resolve(language),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ],
              ),
            ),

            // Two ways into the corpus, which the screen did not offer at all:
            // a reader arrived at a page with four names on it and no route to
            // the other hundred and eighty-seven.
            _TaxonomyStrip(
              key: const ValueKey<String>('home-strip-tradition'),
              title: l10n.homeBrowseByTradition,
              axis: 'tradition',
              terms: _topTerms(TaxonomyKind.tradition),
              language: language,
            ),
            _TaxonomyStrip(
              key: const ValueKey<String>('home-strip-branch'),
              title: l10n.homeBrowseByBranch,
              axis: 'branch',
              terms: _topTerms(TaxonomyKind.branch),
              language: language,
            ),

            const SizedBox(height: Spacing.xl),
            SectionHeader(
              title: l10n.homeStartHere,
              trailing: TextButton.icon(
                onPressed: () => _surpriseMe(context),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(l10n.homeSurpriseMe),
              ),
            ),
            const SizedBox(height: Spacing.md),
            _EntryGrid(
              philosophers: entryPoints,
              columns: columns,
              language: language,
            ),
          ],
        ),
      ),
    );
  }

  /// The taxonomy terms with the most entries behind them, in editorial order.
  ///
  /// Most rather than all: this is a doorway, not the filter itself, and a row
  /// of thirty-six chips on a front page is a menu pretending to be a welcome.
  List<TaxonomyTerm> _topTerms(TaxonomyKind kind) {
    final counts = <String, int>{};
    for (final philosopher in corpus.philosophers) {
      final ids = kind == TaxonomyKind.tradition
          ? philosopher.traditions
          : philosopher.branches;
      for (final id in ids) {
        for (final ancestor in corpus.taxonomy.ancestryOf(id)) {
          counts[ancestor] = (counts[ancestor] ?? 0) + 1;
        }
      }
    }
    final terms =
        counts.keys
            .map((id) => corpus.taxonomy[id])
            .nonNulls
            .where((term) => term.kind == kind)
            .toList()
          ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    final top = terms.take(8).toList()..sort();
    return top;
  }

  void _surpriseMe(BuildContext context) {
    final entities = corpus.allEntities.toList();
    if (entities.isEmpty) return;
    final choice = entities[math.Random().nextInt(entities.length)];
    context.push(choice.ref.route);
  }
}

/// A row of taxonomy chips that opens Explore already filtered.
///
/// The front page had no route into the corpus beyond four cards and a random
/// button. These are doorways: eight terms rather than all thirty-six, because
/// a front page full of chips is a menu pretending to be a welcome.
class _TaxonomyStrip extends StatelessWidget {
  const _TaxonomyStrip({
    required this.title,
    required this.axis,
    required this.terms,
    required this.language,
    super.key,
  });

  final String title;
  final String axis;
  final List<TaxonomyTerm> terms;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(title: title),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (final term in terms)
                ActionChip(
                  label: Text(term.name.resolve(language)),
                  onPressed: () =>
                      context.go('/explore?axis=$axis&term=${term.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The entry points, laid out for the width available.
class _EntryGrid extends StatelessWidget {
  const _EntryGrid({
    required this.philosophers,
    required this.columns,
    required this.language,
  });

  final List<Philosopher> philosophers;
  final int columns;
  final AppLanguage language;

  /// Matches the grid on the explore screen, so a card is the same object in
  /// both places rather than nearly the same.
  static const double _cardHeight = 220;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    Widget card(Philosopher philosopher, int index) => EntranceAnimation(
      index: index,
      child: EntityCard(
        title: philosopher.name.resolve(language),
        summary: philosopher.oneLine.resolve(language),
        maxSummaryLines: ResponsiveLayout.summaryLines(context),
        meta: AppDates.lifeSpan(philosopher.life, language, l10n),
        onTap: () => context.push(philosopher.ref.route),
      ),
    );

    if (columns == 1) {
      return Column(
        children: <Widget>[
          for (var i = 0; i < philosophers.length; i++) ...<Widget>[
            card(philosophers[i], i),
            const SizedBox(height: Spacing.md),
          ],
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: Spacing.md,
        crossAxisSpacing: Spacing.md,
        mainAxisExtent: _cardHeight,
      ),
      itemCount: philosophers.length,
      itemBuilder: (context, index) => card(philosophers[index], index),
    );
  }
}
