import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/gradients.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/responsive.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/gradient_surfaces.dart';
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

  /// The greeting for the current hour.
  ///
  /// Small, and it does most of the work of making the screen feel addressed
  /// to somebody rather than published at them.
  String _greeting(AppL10n l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 18) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
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
                        // The product still names itself, but as a masthead
                        // rather than as a title block: a display-sized name
                        // and a tagline every single visit is a splash screen
                        // that never goes away.
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l10n.appName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => context.go(AppRouter.search),
                              icon: const Icon(Icons.search),
                              tooltip: l10n.navSearch,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.surfaceContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.xl),
                        Text(
                          _greeting(l10n),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          l10n.homeGreetingLead,
                          style: theme.textTheme.displaySmall?.copyWith(
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // The quotation is the screen's one hero, so it gets the gradient,
            // the deep shadow and the whole width — which it did not, because
            // it sat inside the reading column above and stopped 350 pixels
            // short of the tiles beneath it on a desktop, lining its right
            // edge up with nothing. It is out here now, on the content measure
            // the rest of the page uses. The quotation *inside* keeps the
            // reading measure: an aligned edge is worth having, a 1,000-pixel
            // line of prose is not.
            if (quote != null) ...<Widget>[
              const SizedBox(height: Spacing.xl),
              EntranceAnimation(
                index: step++,
                child: _DailyQuoteHero(
                  quote: quote,
                  language: language,
                  label: l10n.homeDailyIdea,
                  speakerName:
                      corpus
                          .philosopher(quote.speakerId)
                          ?.name
                          .resolve(language) ??
                      quote.speakerId,
                  sourceLabel: quoteSourceLabel(quote, corpus.source, language),
                  onTap: () => context.push(quote.speakerRef.route),
                ),
              ),
              const SizedBox(height: Spacing.xxl),
            ],

            // A grid rather than a stack of rows. A list of links tells a
            // reader what exists; a grid tells them how many kinds of thing
            // exist, which is the question somebody opening a reference work
            // for the first time actually has.
            EntranceAnimation(
              index: step++,
              child: SectionHeader(title: l10n.homeSections),
            ),
            const SizedBox(height: Spacing.md),
            EntranceAnimation(
              index: step++,
              child: _SectionTiles(columns: columns == 1 ? 2 : columns),
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
        mainAxisExtent: EntityCard.gridExtent(context),
      ),
      itemCount: philosophers.length,
      itemBuilder: (context, index) => card(philosophers[index], index),
    );
  }
}

/// The daily quotation, given the screen's only gradient.
///
/// The old card was a gold-tinted rectangle carrying the quotation, the
/// speaker, the attribution badge and the full attribution caveat — four
/// registers of type in one box, and the caveat, which is the longest text on
/// the screen, was set at the same weight as the quotation itself. Here the
/// hero carries the line and the name; the caveat moves under the card where a
/// footnote belongs, which is what it is.
class _DailyQuoteHero extends StatelessWidget {
  const _DailyQuoteHero({
    required this.quote,
    required this.language,
    required this.label,
    required this.speakerName,
    required this.sourceLabel,
    required this.onTap,
  });

  final Quote quote;
  final AppLanguage language;
  final String label;
  final String speakerName;

  /// The text and place the words come from, or `null` when the quotation
  /// carries no citation.
  final String? sourceLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caveat = quote.needsCaveat
        ? TaxonomyLabels.attributionExplanation(quote.attribution)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The screen's one live thing, so it is the one thing that blooms —
        // three passes on arrival and then a steady glow. Everything else on
        // the page is quiet enough for that to mean something.
        PulsingGlow(
          colour: theme.colorScheme.primary,
          strength: 0.9,
          borderRadius: Radii.surfaceRadius,
          child: GradientCard(
            gradient: AppGradients.hero,
            strongShadow: false,
            onTap: onTap,
            padding: const EdgeInsets.all(Spacing.xl),
            semanticLabel:
                '$label. ${quote.text.resolve(language)} — $speakerName',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.format_quote_rounded,
                      size: 18,
                      color: AppGradients.onGradientMuted,
                    ),
                    const SizedBox(width: Spacing.sm),
                    // Flexible, because a caption beside an icon is still text
                    // and text grows: at 1.5x on a 320-wide phone this row ran
                    // 34 pixels off the card.
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppGradients.onGradientMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                // The card takes the content measure so its edge lines up with
                // the tiles below; the quotation keeps the reading measure, so
                // a wide window does not hand the reader a thousand-pixel line
                // to track back across.
                ReadingColumn(
                  alignToStart: true,
                  child: Text(
                    quote.text.resolve(language),
                    style: AppTypography.quote(
                      quote.text.resolvedLanguage(language),
                    ).copyWith(color: AppGradients.onGradient),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '— $speakerName',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppGradients.onGradient,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: AppGradients.onGradientMuted,
                    ),
                  ],
                ),
                // The source, under the name. A quotation on the front page
                // with no way to trace it is the shape of the problem this
                // product exists to avoid.
                if (sourceLabel != null) ...<Widget>[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    sourceLabel!,
                    style: AppTypography.citation(language)
                        .copyWith(color: AppGradients.onGradientMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (caveat != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Text(
              caveat.resolve(language),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The grid of the app's sections.
class _SectionTiles extends StatelessWidget {
  const _SectionTiles({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final tiles =
        <
          ({
            IconData icon,
            String title,
            String caption,
            String route,
            Color accent,
          })
        >[
          (
            icon: Icons.school_outlined,
            title: l10n.primerTitle,
            caption: l10n.homeTilePrimerCaption,
            route: AppRouter.primer,
            accent: scheme.primary,
          ),
          (
            icon: Icons.menu_book_outlined,
            title: l10n.glossaryTitle,
            caption: l10n.homeTileGlossaryCaption,
            route: AppRouter.glossary,
            accent: scheme.secondary,
          ),
          (
            icon: Icons.explore_outlined,
            title: l10n.homeTileExplore,
            caption: l10n.homeTileExploreCaption,
            route: AppRouter.explore,
            accent: scheme.tertiary,
          ),
          (
            icon: Icons.search_outlined,
            title: l10n.homeTileSearch,
            caption: l10n.homeTileSearchCaption,
            route: AppRouter.search,
            accent: scheme.primary,
          ),
          (
            icon: Icons.bookmark_border,
            title: l10n.homeTileLibrary,
            caption: l10n.homeTileLibraryCaption,
            route: AppRouter.library,
            accent: scheme.secondary,
          ),
        ];

    // Sized by extent, not by column count. A fixed count with an aspect ratio
    // ties the tile's height to the window's width, and on a tablet that
    // produced two 580-pixel squares holding an icon and six words.
    //
    // The height is then measured from the strings that will actually be in
    // it. Two guessed constants have already been wrong here — 1.15 overflowed
    // an English phone by twelve pixels, and the 178 that replaced it
    // overflowed a Persian one by a single pixel — and a third guess would
    // only be right until somebody turned their text size up.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _maxTileWidth).ceil().clamp(
          1,
          tiles.length,
        );
        final width =
            (constraints.maxWidth - Spacing.md * (columns - 1)) / columns;
        final scaler = MediaQuery.textScalerOf(context);

        double lines(String text, TextStyle? style, int maxLines) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: maxLines,
          )..layout(maxWidth: width - Spacing.lg * 2);
          final height = painter.height;
          painter.dispose();
          return height;
        }

        var tallest = 0.0;
        for (final tile in tiles) {
          final height =
              lines(tile.title, theme.textTheme.titleSmall, 2) +
              Spacing.xxs +
              lines(tile.caption, theme.textTheme.bodySmall, 2);
          if (height > tallest) tallest = height;
        }

        // The icon chip, the gap the tile keeps between it and the words, and
        // the tile's own padding.
        final extent = _iconChipHeight + Spacing.lg + tallest + Spacing.lg * 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: Spacing.md,
            crossAxisSpacing: Spacing.md,
            mainAxisExtent: extent,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            final tile = tiles[index];
            return EntranceAnimation(
              index: index,
              child: TileCard(
                icon: tile.icon,
                title: tile.title,
                caption: tile.caption,
                accent: tile.accent,
                // Tabs inside the shell are switched, not pushed: pushing
                // Explore on top of Home leaves the reader with a back arrow
                // where the navigation bar already says where they are.
                onTap: () => switch (tile.route) {
                  AppRouter.explore ||
                  AppRouter.search ||
                  AppRouter.library => context.go(tile.route),
                  _ => context.push(tile.route),
                },
              ),
            );
          },
        );
      },
    );
  }

  /// The widest a tile is allowed to be before another column is added.
  static const double _maxTileWidth = 220;

  /// The icon chip's height: the glyph plus its padding.
  static const double _iconChipHeight = 22 + Spacing.md * 2;
}
