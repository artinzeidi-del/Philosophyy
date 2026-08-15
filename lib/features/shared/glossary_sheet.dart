import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Shows what a word means, without taking the reader off the page.
///
/// ## Why a sheet rather than a link to the glossary
///
/// The reader is mid-sentence. The whole value of the feature is that they
/// find out what the word means and carry on reading the same paragraph — a
/// navigation would cost them their place, and getting back would cost them
/// the thread. So the definition arrives over the page and leaves it intact
/// underneath.
///
/// The sheet offers the full entry when the corpus has one, which is the case
/// where leaving the page is worth it and is the reader's decision to make.
Future<void> showGlossaryTerm(
  BuildContext context,
  GlossaryTerm term,
  AppLanguage language,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  // The page stays legible behind the sheet: a definition is a footnote, not a
  // new screen, and dimming the article to black would say otherwise.
  barrierColor: Colors.black.withValues(alpha: 0.28),
  builder: (context) => _GlossarySheet(term: term, language: language),
);

class _GlossarySheet extends StatelessWidget {
  const _GlossarySheet({required this.term, required this.language});

  final GlossaryTerm term;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final native = term.nativeTerm;
    final long = term.longDefinition;
    final conceptId = term.conceptId;

    return Directionality(
      textDirection: language == AppLanguage.fa
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.xxl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                term.term.resolve(language),
                style: theme.textTheme.headlineSmall,
              ),
              if (native != null) ...<Widget>[
                const SizedBox(height: Spacing.xxs),
                Text(
                  <String?>[
                    native,
                    term.transliteration,
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: Spacing.md),
              Text(
                term.shortDefinition.resolve(language),
                style: AppTypography.reading(
                  term.shortDefinition.resolvedLanguage(language),
                ).copyWith(color: theme.colorScheme.onSurface),
              ),
              if (long != null) ...<Widget>[
                const SizedBox(height: Spacing.md),
                Text(
                  long.resolve(language),
                  style: AppTypography.reading(long.resolvedLanguage(language))
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: Spacing.lg),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: <Widget>[
                  if (conceptId != null)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(
                          EntityRef(EntityKind.concept, conceptId).route,
                        );
                      },
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text(l10n.glossaryOpenEntry),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/glossary?term=${term.id}');
                    },
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: Text(l10n.glossaryOpenGlossary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
