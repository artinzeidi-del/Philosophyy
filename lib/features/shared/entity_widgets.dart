import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// A small, non-interactive label — a branch, a tradition, an era.
class TagChip extends StatelessWidget {
  const TagChip({required this.label, this.emphasised = false, super.key});

  /// The text to show.
  final String label;

  /// Whether this tag is the most significant one on its row.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: emphasised
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
        border: Border.all(
          color: emphasised ? Colors.transparent : scheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: emphasised
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
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
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return PressableSurface(
      onTap: onTap,
      borderRadius: Radii.surfaceRadius,
      semanticLabel: '$title. $summary',
      // Handed to PressableSurface rather than painted inside the child, so the
      // ink ripple lands on top of the card instead of behind it.
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: Radii.surfaceRadius,
        border: Border.all(
          color: isDark ? scheme.outlineVariant : Colors.transparent,
        ),
        // Light mode gets a soft lift; dark mode separates by surface
        // lightness instead, because a shadow on near-black is invisible and
        // only muddies the edge it was meant to define.
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Dates sit above the name, small and in the accent colour, so a
            // list of people reads chronologically at a glance without the
            // eye having to hunt for the years.
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
            const SizedBox(height: Spacing.sm),
            Text(
              summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.md),
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
          decoration: BoxDecoration(
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
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: colour),
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
  });

  final ContentSection section;
  final AppLanguage language;
  final Source? Function(String) resolveSource;

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
          child: Text(
            section.body.resolve(language),
            style: AppTypography.reading(
              section.body.resolvedLanguage(language),
            ).copyWith(color: theme.colorScheme.onSurface),
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
              final authors = source.authors.join(', ');
              final parts = <String>[
                if (authors.isNotEmpty) authors,
                title,
                ?locator,
              ];
              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xxs),
                child: Text(
                  parts.join(' · '),
                  style: AppTypography.citation(language)
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// A pulled-out quotation with its attribution.
///
/// The attribution badge is not optional decoration: it is the reason this
/// product can show a famous misattributed line at all without becoming part of
/// the problem.
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    required this.quote,
    required this.language,
    required this.speakerName,
    this.onTapSpeaker,
    super.key,
  });

  /// The quotation.
  final Quote quote;

  /// The language to render in.
  final AppLanguage language;

  /// The attributed speaker's display name.
  final String speakerName;

  /// Invoked when the reader taps the speaker's name.
  final VoidCallback? onTapSpeaker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final l10n = AppL10n.of(context);
    final note = quote.attributionNote;
    final actualSource = quote.actualSource;

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
            child: ExcludeSemantics(
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
                const SizedBox(height: Spacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GestureDetector(
                        onTap: onTapSpeaker,
                        child: Text(
                          '— $speakerName',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: semantic.onQuoteSurface,
                          ),
                        ),
                      ),
                    ),
                    AttributionBadge(
                      status: quote.attribution,
                      language: language,
                    ),
                  ],
                ),
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
  const ReadingColumn({required this.child, this.maxWidth, super.key});

  /// The content to constrain.
  final Widget child;

  /// Override for the maximum width.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? Breakpoints.readingMeasure,
      ),
      child: child,
    ),
  );
}
