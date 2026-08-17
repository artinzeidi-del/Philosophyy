import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/skeletons.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Everything the reader has made.
///
/// Deliberately not just a list of bookmarks. A reader who annotated an article
/// without bookmarking it still expects to find it again, and one who was
/// halfway through a long entry expects to be able to get back to it — so the
/// screen is organised by what the reader did, not by which button they pressed.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corpus = ref.watch(corpusProvider);
    final library = ref.watch(libraryProvider);
    final language = ref.watch(activeLanguageProvider);
    final l10n = AppL10n.of(context);

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
          data: (data) => library.isEmpty
              ? EmptyView(
                  icon: Icons.bookmark_border,
                  title: l10n.libraryEmptyTitle,
                  body: l10n.libraryEmptyBody,
                )
              : _LibraryBody(
                  corpus: data,
                  library: library,
                  language: language,
                ),
        ),
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.corpus,
    required this.library,
    required this.language,
  });

  final KnowledgeBase corpus;
  final UserLibrary library;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    final unfinished =
        library.positions
            .where((position) => position.isWorthRestoring)
            .where((position) => !library.isBookmarked(position.target))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Marked passages are split by whether they can still be found in the
    // entry they came from. Copied before sorting: `library.highlights` is the
    // list held in application state, and sorting it in place would mutate
    // state from inside a build.
    final sortedHighlights = <Highlight>[...library.highlights]..sort();
    final placed = <Highlight>[];
    final lost = <Highlight>[];
    for (final highlight in sortedHighlights) {
      (corpus.canPlaceHighlight(highlight, language) ? placed : lost).add(
        highlight,
      );
    }

    var step = 0;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.xxl,
          Spacing.lg,
          Spacing.xxxl,
        ),
        children: <Widget>[
          ReadingColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                EntranceAnimation(
                  index: step++,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.navLibrary,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        AppNumbers.localizeDigits(
                          l10n.libraryItemCount(library.itemCount),
                          language,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xxl),

                if (unfinished.isNotEmpty) ...<Widget>[
                  EntranceAnimation(
                    index: step++,
                    child: SectionHeader(title: l10n.libraryContinueSection),
                  ),
                  for (final position in unfinished)
                    EntranceAnimation(
                      index: step++,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: _TargetCard(
                          corpus: corpus,
                          target: position.target,
                          language: language,
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.xl),
                ],

                if (library.bookmarks.isNotEmpty) ...<Widget>[
                  EntranceAnimation(
                    index: step++,
                    child: SectionHeader(title: l10n.librarySavedSection),
                  ),
                  for (final bookmark in library.bookmarks)
                    EntranceAnimation(
                      index: step++,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: _TargetCard(
                          corpus: corpus,
                          target: bookmark.target,
                          language: language,
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.xl),
                ],

                if (library.notes.isNotEmpty) ...<Widget>[
                  EntranceAnimation(
                    index: step++,
                    child: SectionHeader(title: l10n.libraryNotesSection),
                  ),
                  // Copied before sorting: `library.notes` is the list held in
                  // application state, and sorting it in place would mutate
                  // state from inside a build.
                  for (final note in <Note>[...library.notes]..sort())
                    EntranceAnimation(
                      index: step++,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: _NoteCard(
                          corpus: corpus,
                          note: note,
                          language: language,
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.xl),
                ],

                if (placed.isNotEmpty) ...<Widget>[
                  EntranceAnimation(
                    index: step++,
                    child: SectionHeader(title: l10n.libraryHighlightsSection),
                  ),
                  for (final highlight in placed)
                    EntranceAnimation(
                      index: step++,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: _HighlightCard(
                          corpus: corpus,
                          highlight: highlight,
                          language: language,
                        ),
                      ),
                    ),
                ],

                // Passages that can no longer be found in the entry they came
                // from. The article view drops these silently — correctly, it
                // has nowhere to paint them — which left the reader tapping a
                // card and arriving at a page with nothing marked and no
                // explanation. The explanation was written when the feature
                // was designed and had never been shown.
                if (lost.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Spacing.xl),
                  EntranceAnimation(
                    index: step++,
                    child: SectionHeader(title: l10n.highlightLostTitle),
                  ),
                  EntranceAnimation(
                    index: step++,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: Text(
                        l10n.highlightLostBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  for (final highlight in lost)
                    EntranceAnimation(
                      index: step++,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: _HighlightCard(
                          corpus: corpus,
                          highlight: highlight,
                          language: language,
                          isLost: true,
                        ),
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

/// A card for a marked passage.
///
/// The passage is shown as the reader marked it rather than being looked up in
/// the article, so a highlight remains readable even after the entry it came
/// from has been rewritten underneath it. That is the whole reason [Highlight]
/// stores the excerpt alongside the offsets.
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.corpus,
    required this.highlight,
    required this.language,
    this.isLost = false,
  });

  final KnowledgeBase corpus;
  final Highlight highlight;
  final AppLanguage language;

  /// Whether the passage can no longer be found in the entry it came from.
  ///
  /// Drawn in the muted colour the product uses elsewhere for a claim whose
  /// provenance is unknown, rather than in the highlight colour — the mark is
  /// the reader's and is kept, but it no longer points anywhere.
  final bool isLost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        corpus.nameOf(highlight.target)?.resolve(language) ??
        highlight.target.id;

    return PressableSurface(
      onTap: () => context.push(highlight.target.route),
      borderRadius: Radii.surfaceRadius,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: Radii.surfaceRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        // A rule down the marked edge, echoing the highlight in the article so
        // the two read as the same object in two places.
        //
        // Drawn as a border on the text rather than as a stretched sibling in a
        // Row: inside a ListView the cross axis is unbounded, and asking a Row
        // to stretch there hands its children an infinite height and crashes
        // the frame.
        child: Container(
          padding: const EdgeInsetsDirectional.only(start: Spacing.md),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: isLost
                    ? context.semanticColors.unknownProvenance
                    : theme.colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(highlight.excerpt, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card for a saved article, resolved through the corpus.
class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.corpus,
    required this.target,
    required this.language,
  });

  final KnowledgeBase corpus;
  final EntityRef target;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final entity = corpus.resolve(target);

    // An article the reader saved that has since left the corpus. Saying so is
    // better than dropping it silently, which would look like their bookmark
    // vanished.
    if (entity == null) {
      final l10n = AppL10n.of(context);
      return EntityCard(
        title: l10n.notFoundTitle,
        summary: l10n.notFoundBody,
        onTap: () {},
      );
    }

    return EntityCard(
      title: entity.name.resolve(language),
      summary: entity.oneLine.resolve(language),
      onTap: () => context.push(target.route),
    );
  }
}

/// One of the reader's notes, shown with the article it belongs to.
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.corpus,
    required this.note,
    required this.language,
  });

  final KnowledgeBase corpus;
  final Note note;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final title =
        corpus.nameOf(note.target)?.resolve(language) ?? note.target.id;

    return PressableSurface(
      onTap: () => context.push(note.target.route),
      borderRadius: Radii.surfaceRadius,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: Radii.surfaceRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            // The reader's own words are set in the reading face, at reading
            // size — they are content, not metadata.
            Text(note.body, style: theme.textTheme.bodyLarge),
            if (note.isEdited) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              Text(
                l10n.noteEdited,
                style: theme.textTheme.labelSmall?.copyWith(
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
