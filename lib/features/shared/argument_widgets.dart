import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/domain/entities/argument.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// A reconstructed argument, shown as structure rather than as a paragraph.
///
/// ## Why this is not simply prose
///
/// The corpus models arguments as premises, a conclusion, unstated assumptions
/// and objections that each name the premise they deny. That structure was
/// authored, validated by the integrity checks, and rendered nowhere — twelve
/// arguments existed in the content and no screen in the product could show
/// one. Content with no surface is the same defect as a screen with no content,
/// and slightly harder to notice.
///
/// Showing the shape is the point. A reader who can see that an objection
/// denies the third premise and not the first has learned something a
/// paragraph summarising "critics disagree" cannot teach, and it is the one
/// thing a reference work can do that a good essay cannot.
class ArgumentPanel extends StatefulWidget {
  const ArgumentPanel({
    required this.argument,
    required this.language,
    required this.depth,
    required this.resolveSource,
    this.opposedByReader = false,
    this.raisedByName,
    super.key,
  });

  /// The argument to show.
  final Argument argument;

  /// The language to render in.
  final AppLanguage language;

  /// The reader's chosen depth, applied to the argument's own prose the same
  /// way it is applied to every other article in the product.
  final ContentDepth depth;

  /// Resolves a source identifier to a record, for rendering citations.
  final Source? Function(String) resolveSource;

  /// Whether the philosopher whose page this is argued *against* the argument.
  ///
  /// Kant belongs on the ontological argument's page, and a reader arriving
  /// from his entry must not be left thinking he proposed it.
  final bool opposedByReader;

  /// Resolves an objector's identifier to a display name, when one is known.
  final String? Function(String id)? raisedByName;

  @override
  State<ArgumentPanel> createState() => _ArgumentPanelState();
}

class _ArgumentPanelState extends State<ArgumentPanel> {
  /// Objections start collapsed.
  ///
  /// The argument itself is the thing being shown; the objections are the
  /// second question a reader asks, and opening with every reply expanded
  /// turns a legible structure into a wall.
  bool _showObjections = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final l10n = AppL10n.of(context);
    final argument = widget.argument;
    final language = widget.language;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        borderRadius: Radii.surfaceRadius,
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            argument.name.resolve(language),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            argument.oneLine.resolve(language),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          if (widget.opposedByReader) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Badge(
              label: l10n.argumentArguedAgainst,
              color: semantic.scholarlyDisagreement,
            ),
          ],

          // How securely the reconstruction belongs to whoever is named as
          // advancing it. Shown before the prose rather than after the
          // premises, because it changes how the whole panel should be read.
          if (!argument.hasSettledAttribution) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Badge(
              label: l10n.argumentAttributionQualified,
              color: semantic.scholarlyDisagreement,
            ),
            if (argument.attributionNote case final note?) ...<Widget>[
              const SizedBox(height: Spacing.xs),
              Text(
                note.resolve(language),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],

          // The prose comes before the numbered steps: a reader meeting the
          // argument needs to know what question it answers before being shown
          // the machinery that answers it.
          if (!argument.article.isEmpty) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            ArticleView(
              article: argument.article,
              depth: widget.depth,
              language: language,
              resolveSource: widget.resolveSource,
            ),
          ],

          const SizedBox(height: Spacing.lg),
          _Label(l10n.argumentPremises),
          for (var index = 0; index < argument.premises.length; index++)
            _Statement(
              marker: 'P${index + 1}',
              statement: argument.premises[index],
              language: language,
            ),

          const SizedBox(height: Spacing.md),
          _Label(l10n.argumentConclusion),
          _Statement(
            marker: conclusionMarker,
            statement: argument.conclusion,
            language: language,
            emphasised: true,
          ),

          if (argument.assumptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.md),
            _Label(l10n.argumentAssumptions),
            for (final assumption in argument.assumptions)
              _Bullet(text: assumption, language: language),
          ],

          if (argument.objections.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _showObjections = !_showObjections),
                icon: Icon(
                  _showObjections ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  AppNumbers.localizeDigits(
                    l10n.argumentObjections(argument.objections.length),
                    language,
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.duration(context, MotionTokens.quick),
              curve: MotionTokens.standard,
              alignment: Alignment.topCenter,
              child: _showObjections
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final objection in argument.objections)
                          _ObjectionBlock(
                            objection: objection,
                            argument: argument,
                            language: language,
                            raisedByName: widget.raisedByName,
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

/// The siglum standing for the conclusion, beside the P1, P2 … of the
/// premises.
///
/// It was the therefore symbol, ∴, which no bundled font has a glyph for.
/// Flutter web answers a missing glyph by downloading a Noto face from
/// Google's servers, so one character in a widget turned a self-contained,
/// offline-capable reference work into one that reached out to a third party
/// on every article carrying an argument — and drew a broken box in the
/// meantime. Latin sigla are already the convention here, P being Latin in
/// the Persian interface too.
const String conclusionMarker = 'C';

/// One premise or conclusion, with its marker and optional plain restatement.
class _Statement extends StatelessWidget {
  const _Statement({
    required this.marker,
    required this.statement,
    required this.language,
    this.emphasised = false,
  });

  final String marker;
  final ArgumentStatement statement;
  final AppLanguage language;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gloss = statement.gloss;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // A fixed-width gutter rather than a list bullet, so that the markers
          // line up down the argument and an objection saying "denies P2" has
          // something to point at.
          SizedBox(
            width: 34,
            child: Text(
              marker,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  statement.text.resolve(language),
                  style: emphasised
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.bodyMedium,
                ),
                if (gloss != null) ...<Widget>[
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    gloss.resolve(language),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
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

/// One objection, what it denies, who raised it, and the reply.
class _ObjectionBlock extends StatelessWidget {
  const _ObjectionBlock({
    required this.objection,
    required this.argument,
    required this.language,
    required this.raisedByName,
  });

  final Objection objection;
  final Argument argument;
  final AppLanguage language;
  final String? Function(String id)? raisedByName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final l10n = AppL10n.of(context);

    // Premises are shown to the reader as P1, P2 …, so an objection has to name
    // its target in those terms rather than in the content file's identifiers.
    final targets = <String>[
      for (final id in objection.targetStatementIds)
        if (argument.conclusion.id == id)
          conclusionMarker
        else
          'P${argument.premises.indexWhere((p) => p.id == id) + 1}',
    ].where((label) => label != 'P0').toList();

    final raisedBy = objection.raisedByPhilosopherId;
    final objectorName = raisedBy == null ? null : raisedByName?.call(raisedBy);

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          borderRadius: Radii.cardRadius,
          color: theme.colorScheme.surface,
          border: BorderDirectional(
            start: BorderSide(color: semantic.scholarlyDisagreement, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: <Widget>[
                _Badge(
                  label: targets.isEmpty
                      ? l10n.argumentTargetsWhole
                      : l10n.argumentTargets(targets.join(', ')),
                  color: semantic.scholarlyDisagreement,
                ),
                if (objectorName != null)
                  _Badge(
                    label: l10n.argumentRaisedBy(objectorName),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              objection.text.resolve(language),
              style: theme.textTheme.bodyMedium,
            ),
            for (final reply in objection.replies) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              _Label(l10n.argumentReply),
              const SizedBox(height: Spacing.xxs),
              Text(
                reply.resolve(language),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.language});

  final LocalizedText text;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text('—', style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              text.resolve(language),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
