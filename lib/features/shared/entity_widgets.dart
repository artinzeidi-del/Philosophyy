import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/decorative.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/gradients.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/core/format/bidi_text.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/core/search/glossary_matcher.dart';
import 'package:philosophyy/core/search/text_normalizer.dart';
import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// The smallest a control may be before a finger starts missing it.
///
/// Android's accessibility guideline asks for forty-eight logical pixels and
/// Apple's for forty-four points; the larger figure satisfies both.
const double minimumTapTarget = 48;

/// A small label — a branch, a tradition, an era.
///
/// Interactive only where [onTap] is given. On an article the chips name the
/// tradition and the branches the entry is filed under, and those are the
/// obvious next places to go, so there they navigate; used as a caption
/// elsewhere they stay inert.
class TagChip extends StatelessWidget {
  const TagChip({
    required this.label,
    this.emphasised = false,
    this.onTap,
    super.key,
  });

  /// The text to show.
  final String label;

  /// Whether this tag is the most significant one on its row.
  final bool emphasised;

  /// Where this tag leads, if anywhere.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tap = onTap;

    // Both variants are glass pills. The emphasised one is not a solid block
    // of the container colour — that was legible but it read as a filled
    // button sitting among the glass, and a tag is not something to press. It
    // is tinted, outlined and lettered in the accent instead, which says
    // "this one matters" without changing what kind of object it is.
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasised
            ? scheme.primary.withValues(alpha: 0.14)
            : Glass.fill(context, tint: scheme.surfaceContainerHigh),
        borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
        border: Border.all(
          color: emphasised
              ? scheme.primary.withValues(alpha: 0.45)
              : Glass.border(context),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: emphasised ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );

    if (tap == null) return pill;
    // The pill is 25 pixels tall, which is right for a label and far too small
    // for a finger. Making these chips interactive without giving them a hit
    // area was a defect introduced with the interaction itself; the guideline
    // check named it. The tappable box is padded out to the platform minimum
    // while the pill keeps its size, so the chips still read as labels.
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
        child: InkWell(
          onTap: tap,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
          // `Align` with a `widthFactor`, not a `Container` with an
          // `alignment`. They look interchangeable and are not: a `Container`
          // given an alignment expands to whatever width its parent allows,
          // and the parent here is a `Wrap`, which offers the full row. So
          // every tappable tag took a line to itself — four short words down
          // the left of a phone where three fit across it. It shipped in both
          // languages, and the whole suite passed, because nothing overflowed
          // and nothing was unreadable; it was only wrong to look at.
          //
          // The `widthFactor` makes this box exactly as wide as the pill while
          // `minHeight` keeps the finger target the reason this wrapper exists.
          child: Align(
            widthFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minimumTapTarget),
              child: Center(heightFactor: 1, widthFactor: 1, child: pill),
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading that opens a section of a screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  /// The heading text.
  final String title;

  /// An optional control aligned to the end of the row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      // A `Wrap` rather than a `Row`, because the two are not always going to
      // fit on one line. `Expanded` protects the heading from a wide trailing
      // control and does nothing for the control itself: at 1.5x text the
      // "Surprise me" button overflowed the row by 84 pixels, and no amount of
      // flex on the other child can make a button narrower than its label.
      //
      // On one run `spaceBetween` puts the heading at the start and the control
      // at the end, which is the row this replaces. When they no longer fit,
      // the control drops to its own line instead of off the screen.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: Spacing.sm,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A tappable card summarising anything with a name and a one-line summary.
///
/// One card type is used for philosophers, concepts, works and schools, so that
/// the product reads as one system rather than four. What differs between kinds
/// is carried in [meta], not in the layout.
class EntityCard extends StatelessWidget {
  const EntityCard({
    required this.title,
    required this.summary,
    required this.onTap,
    this.meta,
    this.tags = const <String>[],
    this.footnote,
    this.maxSummaryLines,
    this.showMonogram = true,
    super.key,
  });

  /// The entity's name.
  final String title;

  /// The one-line summary.
  final String summary;

  /// Invoked when the card is tapped.
  final VoidCallback onTap;

  /// A short line of context — dates, an author, a period.
  final String? meta;

  /// Up to a few classification tags.
  final List<String> tags;

  /// A quiet line at the foot of the card, used to explain search matches.
  final String? footnote;

  /// Whether to show the coloured initial at the head of the card.
  ///
  /// The product has no portraits and will not invent any, so this is what
  /// gives a list of a hundred and ninety-one names something to recognise by
  /// shape and colour rather than by reading every title in turn. The glyph is
  /// the entity's own initial in its own script, and the colour is derived
  /// from the title, so an entry keeps the same one on every screen.
  final bool showMonogram;

  /// Caps the summary, for layouts that need every card the same height.
  ///
  /// Null in a list, where a card may be as tall as its text; set in a grid,
  /// where a ragged row of different-height cards reads as a mistake.
  final int? maxSummaryLines;

  /// How tall this card is when it is laid out in a grid.
  ///
  /// A grid row is only as tidy as its shortest card, so the height is fixed
  /// and the summary is clamped to match. Fixed in *logical* pixels was the
  /// mistake: the card's header is text, and at 1.5x the name and dates alone
  /// were taller than the 220 the grid allowed, so the card overflowed by 36
  /// pixels however far the summary shrank.
  ///
  /// Scaling the extent by the same factor the text scales by is the only
  /// version of this number that cannot be right at one setting and wrong at
  /// another. The padding does not need to grow with it, which is why the
  /// result has room to spare at 1.0 rather than being tight everywhere.
  static double gridExtent(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_gridExtent);

  static const double _gridExtent = 220;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableSurface(
      onTap: onTap,
      borderRadius: Radii.surfaceRadius,
      semanticLabel: '$title. $summary',
      // Handed to PressableSurface rather than painted inside the child, so the
      // ink ripple lands on top of the card instead of behind it.
      //
      // ## Why this is a gradient and a shadow rather than a flat fill
      //
      // It was `Glass.fill` and a hairline, on the reasoning that a shadow
      // under a translucent panel makes it look printed. On a screen the result
      // was a list of rectangles a shade darker than the page: the translucency
      // was real and there was nothing behind it worth seeing through to, so
      // nothing read as glass.
      //
      // What a pane actually looks like is light on its top edge and a shadow
      // under its bottom one. The gradient supplies the first and `Glass.lift`
      // the second — a tight contact shadow and a wide ambient one, which is
      // what separates an object resting on a surface from a rectangle with a
      // grey edge. The earlier note was right that one heavy shadow looks
      // printed; the answer was a lighter pair, not none.
      decoration: BoxDecoration(
        gradient: Glass.surfaceGradient(context),
        borderRadius: Radii.surfaceRadius,
        border: Border.all(color: Glass.border(context)),
        boxShadow: Glass.lift(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Dates sit above the name, small and in the accent colour, so a
            // list of people reads chronologically at a glance without the
            // eye having to hunt for the years.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showMonogram) ...<Widget>[
                  _Monogram(seed: title),
                  const SizedBox(width: Spacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (meta != null) ...<Widget>[
                        Text(
                          meta!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.secondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                      ],
                      Text(title, style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            // In a grid the card has a fixed height, so the summary is the
            // part that has to give: it takes the room left over and
            // ellipsizes inside it. A plain `Text` with a `Spacer` under it
            // does not — adding the coloured initial made the header a single
            // pixel taller in Persian, and the card overflowed rather than
            // shortening a summary that was already being truncated.
            //
            // In a list there is no fixed height and nothing to distribute, so
            // the summary is left to be as tall as it needs.
            if (maxSummaryLines != null)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Text(
                    summary,
                    maxLines: maxSummaryLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (tags.isNotEmpty) ...<Widget>[
              SizedBox(
                height: maxSummaryLines == null ? Spacing.md : Spacing.sm,
              ),
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: <Widget>[for (final tag in tags) TagChip(label: tag)],
              ),
            ],
            if (footnote != null) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              Text(
                footnote!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A badge stating how reliable a quotation's attribution is.
///
/// Tapping it explains what the status means, because a coloured word teaches
/// nobody anything on its own.
class AttributionBadge extends StatelessWidget {
  const AttributionBadge({
    required this.status,
    required this.language,
    super.key,
  });

  /// The status to display.
  final AttributionStatus status;

  /// The language to render the label in.
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    final colour = switch (status) {
      AttributionStatus.verified => semantic.verified,
      AttributionStatus.probable => semantic.probable,
      AttributionStatus.disputed => semantic.disputed,
      AttributionStatus.misattributed => semantic.misattributed,
      AttributionStatus.unknown => semantic.unknownProvenance,
    };
    final label = TaxonomyLabels.attribution(status).resolve(language);
    final explanation = TaxonomyLabels.attributionExplanation(status)
        .resolve(language);

    return Tooltip(
      message: explanation,
      child: Semantics(
        label: '$label. $explanation',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xxs,
          ),
          // The badge fills itself with the reading surface rather than
          // sitting on whatever it happens to be placed over. Its colour is
          // chosen against that surface and asserted against it; on a
          // quotation card's own fill the same colour came to 4.32:1.
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
            border: Border.all(color: colour),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                switch (status) {
                  AttributionStatus.verified => Icons.check_circle_outline,
                  AttributionStatus.probable => Icons.help_outline,
                  AttributionStatus.disputed => Icons.forum_outlined,
                  AttributionStatus.misattributed => Icons.report_outlined,
                  AttributionStatus.unknown => Icons.remove_circle_outline,
                },
                size: 14,
                color: colour,
              ),
              const SizedBox(width: Spacing.xs),
              // The badge sizes to its label, and the label is text: «محتمل»
              // at 1.5x ran the badge 21 pixels past the card. Flexible lets
              // it wrap inside the pill instead of pushing the pill outward.
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: colour),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says how well established a knowledge-graph connection is.
///
/// A graph draws every edge the same way, which makes every edge look like the
/// same kind of claim. "Aristotle studied under Plato" and "Heraclitus
/// influenced Hegel" are not the same kind of claim, and a reader has no way to
/// tell them apart unless the product says so.
///
/// Nothing is drawn for [RelationConfidence.accepted]: it is the unremarkable
/// middle, and badging every edge would turn the marking into wallpaper that
/// stops carrying information. [RelationConfidence.documented] *is* drawn,
/// because "a text says so" is worth telling a reader who wants to go and read
/// it.
class RelationConfidenceBadge extends StatelessWidget {
  const RelationConfidenceBadge({
    required this.confidence,
    required this.language,
    super.key,
  });

  /// How well established the connection is.
  final RelationConfidence confidence;

  /// The language to render the label in.
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    if (confidence == RelationConfidence.accepted) {
      return const SizedBox.shrink();
    }

    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    // Reusing the attribution palette rather than inventing a second one: the
    // product already teaches the reader that this amber means "probable" and
    // this orange means "contested", and a parallel vocabulary would undo that.
    final colour = switch (confidence) {
      RelationConfidence.documented => semantic.verified,
      RelationConfidence.accepted => semantic.verified,
      RelationConfidence.probable => semantic.probable,
      RelationConfidence.contested => semantic.disputed,
      RelationConfidence.speculative => semantic.unknownProvenance,
    };
    final label = TaxonomyLabels.relationConfidence(confidence)
        .resolve(language);
    final explanation = TaxonomyLabels.relationConfidenceExplanation(confidence)
        .resolve(language);

    return Tooltip(
      message: explanation,
      child: Semantics(
        label: '$label. $explanation',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xs,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
            border: Border.all(color: colour),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colour,
              fontSize: 10.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a passage as something other than settled fact.
class ClaimBadge extends StatelessWidget {
  const ClaimBadge({required this.claim, required this.language, super.key});

  /// The kind of claim being made.
  final ClaimType claim;

  /// The language to render the label in.
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    if (!claim.requiresMarking) return const SizedBox.shrink();

    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    final colour = switch (claim) {
      ClaimType.interpretation => semantic.interpretation,
      ClaimType.scholarlyDisagreement => semantic.scholarlyDisagreement,
      ClaimType.hypothesis => semantic.probable,
      ClaimType.disputed => semantic.disputed,
      ClaimType.fact => semantic.verified,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(width: 3, height: 14, color: colour),
          const SizedBox(width: Spacing.sm),
          Text(
            TaxonomyLabels.claimType(claim).resolve(language),
            style: theme.textTheme.labelSmall?.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}

/// Renders an article at a chosen depth.
///
/// Sections deeper than [depth] are not rendered at all rather than collapsed,
/// because a reader who has chosen the short version should not have to scroll
/// past the long one.
class ArticleView extends StatelessWidget {
  const ArticleView({
    required this.article,
    required this.depth,
    required this.language,
    required this.resolveSource,
    this.highlights = const <Highlight>[],
    this.glossary = const <GlossaryTerm>[],
    this.onTermTapped,
    this.onHighlight,
    this.onRemoveHighlight,
    super.key,
  });

  /// The article to render.
  final Article article;

  /// The reader's chosen depth.
  final ContentDepth depth;

  /// The language to render in.
  final AppLanguage language;

  /// Resolves a source identifier to a record, for rendering citations.
  final Source? Function(String) resolveSource;

  /// The reader's marked passages in this article, across all sections.
  final List<Highlight> highlights;

  /// The words worth marking in this article's prose.
  final List<GlossaryTerm> glossary;

  /// Called when the reader taps a marked word.
  final void Function(GlossaryTerm)? onTermTapped;

  /// Called when the reader marks a passage. Passing `null` makes the article
  /// read-only, which is what every caller outside the article screen wants.
  final void Function(String sectionId, int start, int end, String excerpt)?
  onHighlight;

  /// Called when the reader unmarks a passage.
  final void Function(String highlightId)? onRemoveHighlight;

  @override
  Widget build(BuildContext context) {
    final visible = article.at(depth);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final section in visible) ...<Widget>[
          _SectionView(
            section: section,
            language: language,
            resolveSource: resolveSource,
            highlights: highlights
                .where((it) => it.sectionId == section.id)
                .toList(),
            glossary: glossary,
            onTermTapped: onTermTapped,
            onHighlight: onHighlight,
            onRemoveHighlight: onRemoveHighlight,
          ),
          const SizedBox(height: Spacing.xl),
        ],
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.language,
    required this.resolveSource,
    this.highlights = const <Highlight>[],
    this.glossary = const <GlossaryTerm>[],
    this.onTermTapped,
    this.onHighlight,
    this.onRemoveHighlight,
  });

  final ContentSection section;
  final AppLanguage language;
  final Source? Function(String) resolveSource;
  final List<Highlight> highlights;
  final List<GlossaryTerm> glossary;
  final void Function(GlossaryTerm)? onTermTapped;
  final void Function(String sectionId, int start, int end, String excerpt)?
  onHighlight;
  final void Function(String highlightId)? onRemoveHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final heading = section.heading;
    final fellBackToEnglish =
        section.body.resolvedLanguage(language) != language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (heading != null) ...<Widget>[
          Semantics(
            header: true,
            child: Text(
              heading.resolve(language),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: Spacing.sm),
        ],
        ClaimBadge(claim: section.claimType, language: language),
        if (fellBackToEnglish) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text(
              l10n.translationMissing,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        // The body is rendered in the language it is actually written in, so a
        // fallback to English keeps English typography and direction rather
        // than setting Latin text in a Persian frame.
        Directionality(
          textDirection:
              section.body.resolvedLanguage(language) == AppLanguage.fa
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: _SectionBody(
            sectionId: section.id,
            text: section.body.resolve(language),
            style: AppTypography.reading(
              section.body.resolvedLanguage(language),
            ).copyWith(color: theme.colorScheme.onSurface),
            highlights: highlights,
            language: language,
            glossary: glossary,
            onTermTapped: onTermTapped,
            onHighlight: onHighlight,
            onRemoveHighlight: onRemoveHighlight,
          ),
        ),
        if (section.citations.isNotEmpty) ...<Widget>[
          const SizedBox(height: Spacing.md),
          CitationList(
            citations: section.citations,
            language: language,
            resolveSource: resolveSource,
          ),
        ],
      ],
    );
  }
}

/// One section's prose, selectable and markable.
///
/// ## Why the highlights are re-anchored before painting
///
/// A highlight stores character offsets *and* the text it covered. Content is
/// edited between releases, so the offsets go stale — and painting a stale range
/// would put the reader's mark on a sentence they never marked, which is worse
/// than losing it. [Highlight.reanchoredIn] finds the excerpt again when it has
/// simply moved, and gives up when the passage is gone or has become ambiguous.
/// That logic already existed and had never been called from the interface.
class _SectionBody extends StatefulWidget {
  const _SectionBody({
    required this.sectionId,
    required this.text,
    required this.style,
    required this.highlights,
    required this.language,
    this.glossary = const <GlossaryTerm>[],
    this.onTermTapped,
    this.onHighlight,
    this.onRemoveHighlight,
  });

  final String sectionId;
  final String text;
  final TextStyle style;
  final List<Highlight> highlights;
  final AppLanguage language;

  /// The words worth marking in this prose. Empty disables the feature.
  final List<GlossaryTerm> glossary;

  /// Called when the reader taps a marked word.
  final void Function(GlossaryTerm)? onTermTapped;

  final void Function(String sectionId, int start, int end, String excerpt)?
  onHighlight;
  final void Function(String highlightId)? onRemoveHighlight;

  @override
  State<_SectionBody> createState() => _SectionBodyState();
}

class _SectionBodyState extends State<_SectionBody> {
  /// The reader's current selection in this section, if any.
  ///
  /// Held because the marking control is drawn by the app rather than by the
  /// platform selection toolbar. Flutter's toolbar does not appear on web
  /// desktop at all, so relying on it would have left the feature reachable on
  /// phones and invisible in a browser — which is where this was first tested.
  TextSelection? _selection;

  String get text => widget.text;

  /// The highlights that can still be placed in this text, in reading order and
  /// with overlaps dropped.
  ///
  /// Overlapping marks cannot both be painted, and picking the earlier one is
  /// arbitrary but stable — which matters more here than which one wins, since
  /// the reader sees a mark either way.
  List<Highlight> get _placeable {
    final anchored = <Highlight>[];
    for (final highlight in widget.highlights) {
      final moved = highlight.reanchoredIn(text);
      if (moved != null) anchored.add(moved);
    }
    anchored.sort();
    final result = <Highlight>[];
    var cursor = 0;
    for (final highlight in anchored) {
      if (highlight.start < cursor) continue;
      result.add(highlight);
      cursor = highlight.end;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final placed = _placeable;

    // Two things want to mark up the same string: the reader's highlights and
    // the glossary. They are merged into one ordered list of ranges before any
    // span is built, because building them in two passes is how you end up
    // with a highlight that swallows a term or a term that clips a highlight.
    // Where they collide the highlight wins: it is the reader's own mark.
    final terms = widget.glossary.isEmpty
        ? const <GlossaryMatch>[]
        : GlossaryMatcher.findIn(text, widget.glossary, widget.language);

    final ranges =
        <({int start, int end, Highlight? mark, GlossaryMatch? term})>[
          for (final highlight in placed)
            (
              start: highlight.start,
              end: highlight.end,
              mark: highlight,
              term: null,
            ),
          for (final match in terms)
            if (!placed.any((h) => h.start < match.end && match.start < h.end))
              (start: match.start, end: match.end, mark: null, term: match),
        ]..sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      final content = text.substring(range.start, range.end);
      if (range.mark != null) {
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              backgroundColor: theme.colorScheme.primaryContainer,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        );
      } else {
        final term = range.term!.term;
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              // A dotted underline rather than a colour: a link colour on a
              // word inside a paragraph of philosophy reads as a cross
              // reference to another entry, which this is not — it is a
              // definition that arrives without moving the reader.
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            recognizer: (TapGestureRecognizer()
              ..onTap = () => widget.onTermTapped?.call(term)),
          ),
        );
      }
      cursor = range.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    final canMark = widget.onHighlight != null;
    final selection = _selection;
    final selected =
        selection != null && selection.isValid && !selection.isCollapsed
        ? selection
        : null;
    final overlapping = selected == null
        ? const <Highlight>[]
        : placed
              .where((it) => it.start < selected.end && selected.start < it.end)
              .toList();

    final body = SelectableText.rich(
      TextSpan(style: widget.style, children: spans),
      onSelectionChanged: !canMark
          ? null
          : (value, cause) => setState(() => _selection = value),
      // Selecting text is how a reader marks a passage, so the selection
      // handles have to be reachable — but the article is inside a scroll view,
      // and a long-press that starts a drag would fight the scroll. Flutter's
      // default gestures already resolve that; what it does not do by itself is
      // offer anything to *do* with the selection.
      contextMenuBuilder: !canMark
          ? null
          : (context, editableState) {
              final selection = editableState.textEditingValue.selection;
              final items = <ContextMenuButtonItem>[
                ...editableState.contextMenuButtonItems,
              ];

              if (selection.isValid && !selection.isCollapsed) {
                final start = selection.start;
                final end = selection.end;
                final existing = placed
                    .where((it) => it.start < end && start < it.end)
                    .toList();

                if (existing.isEmpty) {
                  items.add(
                    ContextMenuButtonItem(
                      label: l10n.highlightAdd,
                      onPressed: () {
                        ContextMenuController.removeAny();
                        editableState.hideToolbar();
                        widget.onHighlight!(
                          widget.sectionId,
                          start,
                          end,
                          text.substring(start, end),
                        );
                      },
                    ),
                  );
                } else if (widget.onRemoveHighlight != null) {
                  items.add(
                    ContextMenuButtonItem(
                      label: l10n.highlightRemove,
                      onPressed: () {
                        ContextMenuController.removeAny();
                        editableState.hideToolbar();
                        for (final highlight in existing) {
                          widget.onRemoveHighlight!(highlight.id);
                        }
                      },
                    ),
                  );
                }
              }

              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableState.contextMenuAnchors,
                buttonItems: items,
              );
            },
    );

    if (!canMark || selected == null) return body;

    final canRemove =
        overlapping.isNotEmpty && widget.onRemoveHighlight != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        body,
        const SizedBox(height: Spacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () {
              if (canRemove) {
                for (final highlight in overlapping) {
                  widget.onRemoveHighlight!(highlight.id);
                }
              } else if (overlapping.isEmpty) {
                widget.onHighlight!(
                  widget.sectionId,
                  selected.start,
                  selected.end,
                  text.substring(selected.start, selected.end),
                );
              }
              setState(() => _selection = null);
            },
            icon: Icon(
              canRemove ? Icons.format_clear : Icons.border_color_outlined,
              size: 18,
            ),
            label: Text(canRemove ? l10n.highlightRemove : l10n.highlightAdd),
          ),
        ),
      ],
    );
  }
}

/// One bibliographic record, set as a reference-work entry rather than a link.
///
/// Used where the source *is* the content — the editions of a work — as opposed
/// to [CitationList], where sources are the apparatus behind a claim. A reader
/// choosing which translation to read needs the translator and the edition to
/// be legible, not compressed into a footnote.
class SourceLine extends StatelessWidget {
  const SourceLine({required this.source, required this.language, super.key});

  /// The record to render.
  final Source source;

  /// The language to render in.
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translator = source.translator;
    final detail = <String>[
      if (source.authors.isNotEmpty) source.authors.join(', '),
      ?translator,
      ?source.edition,
      ?source.publisher,
      if (source.year != null) '${source.year!.year}',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.menu_book_outlined,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // What a reader needs in order to use the citation: that "38a"
              // is a Stephanus number, that the Enchiridion was written down
              // by a student, that FitzGerald's Khayyam is a paraphrase. A
              // hundred and forty-four sources carry one and none was shown,
              // so a locator meaningful to an editor meant nothing to a
              // reader.
              //
              // A citation the reader cannot follow is the appearance of
              // sourcing, so a source that records an address becomes one
              // control carrying all three lines. Only such a source does:
              // most of this bibliography is primary texts cited by a
              // canonical locator — a Stephanus number, a Bekker number —
              // which is stable across every edition and better than a link.
              if (source.url case final url?)
                _SourceLink(
                  url: url,
                  language: language,
                  children: _citationLines(context, source, detail, language),
                )
              else
                ..._citationLines(context, source, detail, language),
            ],
          ),
        ),
      ],
    );
  }
}

/// The title of a source, its bibliographic detail, and the note about how it
/// is cited — the part that is the same whether or not it can be opened.
List<Widget> _citationLines(
  BuildContext context,
  Source source,
  List<String> detail,
  AppLanguage language,
) {
  final theme = Theme.of(context);
  return <Widget>[
    Text(source.title.resolve(language), style: theme.textTheme.bodyMedium),
    if (detail.isNotEmpty)
      Text(
        joinIsolated(detail, ' · '),
        style: AppTypography.citation(language)
            .copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    if (source.rightsNote case final note?)
      Text(
        note.resolve(language),
        style: AppTypography.citation(language).copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
  ];
}

/// The address of a source, as something the reader can open.
///
/// The address is shown rather than hidden behind the title, because a reader
/// deciding whether to follow a citation wants to see where it goes — and
/// because on a platform where opening fails there is then still something to
/// copy.
class _SourceLink extends StatelessWidget {
  const _SourceLink({
    required this.url,
    required this.language,
    this.children = const <Widget>[],
  });

  final String url;
  final AppLanguage language;

  /// The rest of the citation, drawn above the address and tappable with it.
  final List<Widget> children;

  /// Opens [url], and says so when it cannot.
  ///
  /// `launchUrl` is documented to throw when the platform has nothing that can
  /// handle the address — a device with no browser association, a webview, a
  /// locked-down install. Fired and forgotten, that would surface as an
  /// uncaught async error and, to the reader, as a tap that did nothing.
  ///
  /// Telling them costs a line and leaves them somewhere useful: the address
  /// is printed above rather than hidden behind the title, so a link that will
  /// not open is still one they can copy.
  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = AppL10n.of(context).linkCouldNotOpen;
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } on Object catch (error) {
      debugPrint('Could not open $url: $error');
    }
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The whole citation is the target, not the address line.
    //
    // A one-line address in citation type is a nineteen-pixel box, and a
    // finger needs forty-eight. Padding the line to reach it would put a
    // finger's worth of white space between every citation and the next, so
    // the tap area is taken from what is already there: the title, the note
    // about how the text is cited, and the address are one control, and
    // tapping any of them opens it. That is also what a reader expects — the
    // whole entry reads as one thing.
    //
    // Flutter's tap-target guideline did not catch this. Pointed at this
    // widget it passes even when the link is deliberately shrunk to eight
    // pixels, so the size is measured directly in the test instead.
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => unawaited(_open(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minimumTapTarget),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ...children,
              Text(
                url,
                textDirection: TextDirection.ltr,
                style: AppTypography.citation(language).copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary.withValues(
                    alpha: 0.4,
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

/// The list of sources backing a passage.
class CitationList extends StatelessWidget {
  const CitationList({
    required this.citations,
    required this.language,
    required this.resolveSource,
    super.key,
  });

  /// The citations to render.
  final List<Citation> citations;

  /// The language to render in.
  final AppLanguage language;

  /// Resolves a source identifier to a record.
  final Source? Function(String) resolveSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final citation in citations)
          Builder(
            builder: (context) {
              final source = resolveSource(citation.sourceId);
              if (source == null) return const SizedBox.shrink();
              final locator = citation.locator;
              final title = source.title.resolve(language);
              final authors = source.authorsIn(language).join('، ');
              final parts = <String>[
                if (authors.isNotEmpty) authors,
                title,
                ?locator,
              ];
              // The apparatus belongs where the reader looks for it. These
              // lines were added to the widget that renders a work's editions,
              // and this — the Sources list at the foot of every article — is
              // the list a reader actually goes to, so it printed a title and
              // a locator and nothing that could be acted on.
              //
              // Where there is an address the whole entry is one control: the
              // address line alone is a nineteen-pixel target and a finger
              // needs forty-eight.
              final lines = <Widget>[
                Text(
                  joinIsolated(parts, ' · '),
                  style: AppTypography.citation(language)
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (source.rightsNote case final note?)
                  Text(
                    note.resolve(language),
                    style: AppTypography.citation(language).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ];

              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: source.url == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lines,
                      )
                    : _SourceLink(
                        url: source.url!,
                        language: language,
                        children: lines,
                      ),
              );
            },
          ),
      ],
    );
  }
}

/// Where a quotation comes from, as one line: the text and the place in it.
///
/// The speaker is already named beside the badge, so the source's authors are
/// left out — repeating "Nietzsche" under a line signed "— Nietzsche" says
/// nothing. What is missing without this is the part a reader can act on: the
/// title to open and the section to turn to.
///
/// Returns `null` when the quotation carries no citation, or names a source
/// that is not in the corpus, so the caller renders nothing rather than an
/// empty line.
String? quoteSourceLabel(
  Quote quote,
  Source? Function(String id) resolveSource,
  AppLanguage language,
) {
  final citation = quote.citation;
  if (citation == null) return null;
  final source = resolveSource(citation.sourceId);
  if (source == null) return null;
  return joinIsolated(<String>[
    source.title.resolve(language),
    ?citation.locator,
  ], ' · ');
}

/// A pulled-out quotation with its attribution.
///
/// The attribution badge is not optional decoration: it is the reason this
/// product can show a famous misattributed line at all without becoming part of
/// the problem.
///
/// Neither is the source line under it. Every quotation in the corpus records
/// the text and the place in it that the words come from, and for a long time
/// this card displayed none of that — the badge said «تأییدشده» and gave the
/// reader no way to go and check. A verification a reader cannot repeat is a
/// claim, not a verification.
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    required this.quote,
    required this.language,
    required this.speakerName,
    this.resolveSource,
    this.onTapSpeaker,
    super.key,
  });

  /// The quotation.
  final Quote quote;

  /// The language to render in.
  final AppLanguage language;

  /// The attributed speaker's display name.
  final String speakerName;

  /// Looks up the cited source, so the card can say where the words are from.
  ///
  /// Optional only because a caller may have no corpus to hand; every caller
  /// that has one should pass it.
  final Source? Function(String id)? resolveSource;

  /// Invoked when the reader taps the speaker's name.
  final VoidCallback? onTapSpeaker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final l10n = AppL10n.of(context);
    final note = quote.attributionNote;
    final actualSource = quote.actualSource;
    final resolve = resolveSource;
    final sourceLabel = resolve == null
        ? null
        : quoteSourceLabel(quote, resolve, language);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: Radii.surfaceRadius,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[
            semantic.quoteSurface,
            Color.lerp(semantic.quoteSurface, semantic.quoteAccent, 0.12)!,
          ],
        ),
        // Directional rather than left: in Persian the accent belongs on the
        // start edge, which is the right-hand side of the screen.
        border: BorderDirectional(
          start: BorderSide(color: semantic.quoteAccent, width: 3),
        ),
      ),
      child: Stack(
        children: <Widget>[
          // A printer's quotation mark, set large and very faint. It says "these
          // are somebody's words" before a single word is read, which the
          // attribution badge underneath cannot do because it is read last.
          PositionedDirectional(
            top: -10,
            end: 10,
            child: Decorative(
              child: Text(
                '”',
                style: TextStyle(
                  fontFamily: AppTypography.serifFamily,
                  fontSize: 92,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: semantic.quoteAccent.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  quote.text.resolve(language),
                  style: AppTypography.quote(
                    quote.text.resolvedLanguage(language),
                  ).copyWith(color: semantic.onQuoteSurface),
                ),
                // The words as they were written, when the corpus has them.
                //
                // Forty-one quotations carry the original and nothing showed
                // it: the app that exists so a reader can check a quotation
                // against its source held the source's own words and printed
                // only a translation. It is set quiet but not small, the same
                // treatment a name in its original script gets in the
                // masthead, and it takes its direction from the script — Greek
                // runs left to right in a Persian interface, Persian runs
                // right to left in an English one.
                if (quote.originalText case final original?) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  Text(
                    original,
                    textDirection: TextNormalizer.containsArabicScript(original)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: AppTypography.serifFamily,
                      fontFamilyFallback: AppTypography.fallbacksFor(language),
                      height: 1.6,
                      color: semantic.onQuoteSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  // The romanisation under the script it romanises, so a
                  // reader who cannot read Devanagari can still say the line.
                  // Set apart by size and italic rather than by going fainter:
                  // at 0.6 alpha it measured 4.19:1 on the light quote surface
                  // and 3.73:1 on the dark, both under the 4.5:1 this app
                  // holds body text to.
                  if (quote.transliteration case final roman?)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.xs),
                      child: Text(
                        roman,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: AppTypography.serifFamily,
                          fontFamilyFallback: AppTypography.fallbacksFor(
                            language,
                          ),
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: semantic.onQuoteSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: Spacing.md),
                // A `Wrap`, because the badge beside the name cannot shrink:
                // it is a word in a pill, and `Expanded` on the name only
                // moves the problem. At 1.5x the two ran 27 pixels past the
                // card's edge, and on one run this is the same row.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: Spacing.sm,
                  children: <Widget>[
                    GestureDetector(
                      onTap: onTapSpeaker,
                      child: Text(
                        '— $speakerName',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: semantic.onQuoteSurface,
                        ),
                      ),
                    ),
                    AttributionBadge(
                      status: quote.attribution,
                      language: language,
                    ),
                  ],
                ),
                if (sourceLabel != null) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.menu_book_outlined,
                          size: 14,
                          color: semantic.onQuoteSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.xs),
                      Expanded(
                        child: Text(
                          sourceLabel,
                          // Full strength, not a faded one. Dimming this to
                          // 0.82 put it at 4.41:1 on the dark quote surface —
                          // under the 4.5:1 floor, and caught by the painted
                          // contrast sweep. The smaller citation face is what
                          // sets this line apart from the note; the colour
                          // does not have to.
                          style: AppTypography.citation(language)
                              .copyWith(color: semantic.onQuoteSurface),
                        ),
                      ),
                    ],
                  ),
                ],
                if (quote.needsCaveat) ...<Widget>[
                  const SizedBox(height: Spacing.md),
                  Text(
                    l10n.attributionCaveat,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantic.onQuoteSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (note != null) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  Text(
                    note.resolve(language),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: semantic.onQuoteSurface,
                    ),
                  ),
                ],
                if (actualSource != null) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '${l10n.actualSourceLabel}: ${actualSource.resolve(language)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantic.onQuoteSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Constrains its child to a comfortable reading measure and centres it.
///
/// Long-form text set across the full width of a tablet or desktop window is
/// physically tiring to read, whatever else is right about the typography.
class ReadingColumn extends StatelessWidget {
  const ReadingColumn({
    required this.child,
    this.maxWidth,
    this.alignToStart = false,
    super.key,
  });

  /// The content to constrain.
  final Widget child;

  /// Override for the maximum width.
  final double? maxWidth;

  /// Whether to hold the prose against the leading edge instead of centring
  /// it in the space available.
  ///
  /// Centring is right when the column is the only thing on the page. It is
  /// wrong when prose sits above a grid of cards, because the two then have
  /// different left edges — on a desktop the home screen's heading started
  /// 180 logical pixels to the right of the cards under it, which reads as a
  /// misalignment rather than as a measure.
  final bool alignToStart;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignToStart
        ? AlignmentDirectional.topStart
        : Alignment.topCenter,
    // `width: infinity` under a maxWidth constraint means "the measure, or the
    // window if the window is narrower" — not "as wide as the content happens
    // to be". Without it the column shrink-wraps, and a centred column that
    // shrink-wraps moves: the library's heading sat 260 pixels further right
    // when the only thing in it was a two-character highlight than when it
    // held a saved entry.
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? Breakpoints.readingMeasure,
      ),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// The glyph shown on an entity's coloured chip.
///
/// Taken with `characters` rather than `title[0]`, because a Dart string index
/// returns a UTF-16 code unit: on «افلاطون» that is fine, on a name beginning
/// with a character outside the basic plane it is half of one and renders as a
/// replacement box.
///
/// A leading English article is skipped. "The Forms" was showing a T, which
/// tells a reader nothing and files every title beginning with an article
/// under the same letter — and the article is not what anyone would look it up
/// under.
String entityInitial(String title) {
  var trimmed = title.trim();
  for (final article in const <String>['The ', 'A ', 'An ']) {
    if (trimmed.startsWith(article)) {
      trimmed = trimmed.substring(article.length).trim();
      break;
    }
  }
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

/// A coloured chip carrying one glyph, standing in for a portrait.
///
/// The product holds no images of philosophers and is not going to generate
/// any — a plausible-looking portrait of someone nobody has a likeness of is
/// the same defect as a plausible-looking citation. This is the honest
/// substitute: a real letter from the entity's own name, on a colour derived
/// from its identifier so it is stable across every screen.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final gradient = AppGradients.forSeed(seed);
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
        boxShadow: AppGradients.shadowFor(gradient.colors.last),
      ),
      child: Text(
        entityInitial(seed),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: AppGradients.onGradient, height: 1),
      ),
    );
  }
}
