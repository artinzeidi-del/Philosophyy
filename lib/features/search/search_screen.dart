import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/glossary_sheet.dart';
import 'package:philosophyy/features/shared/skeletons.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Search across the whole corpus, in either language.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  /// How many results are animated in. Roughly one screenful.
  static const int _animatedResults = 6;

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));

    // Build the index now, while this screen is painting, rather than on the
    // reader's first keystroke. It is half a second of work on the UI isolate,
    // and it used to land the moment they pressed a key — which is why typing
    // felt like the app had stopped. Nothing here waits for it: the empty
    // state below is drawn from the corpus, not the index.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) warmSearchIndex(ref);
    });
  }

  /// Runs [query] as though the reader had typed it.
  void _runQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    ref.read(searchQueryProvider.notifier).set(query);
  }

  /// Replaces the word the reader is in the middle of with [completion].
  ///
  /// The earlier words are kept exactly as typed. A completion that rewrote the
  /// whole query would undo a reader who had already narrowed it.
  void _completeLastWord(String completion) {
    final query = ref.read(searchQueryProvider);
    final parts = query.split(' ');
    parts[parts.length - 1] = completion;
    _runQuery('${parts.join(' ')} ');
  }

  /// Opens [route], recording what was searched for on the way.
  ///
  /// Recorded here rather than as the reader types: a history built from
  /// keystrokes fills with every prefix of every word.
  void _openResult(String route) {
    unawaited(
      ref
          .read(recentSearchesProvider.notifier)
          .record(ref.read(searchQueryProvider)),
    );
    context.push(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corpus = ref.watch(corpusProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LamplightBackdrop(
        intensity: 0.7,
        // A corpus that failed to load left this screen telling the reader
        // "nothing found for 'plato' — check the spelling", which blames them
        // for the app's own failure and offers no way out. Every other screen
        // says what happened and gives a way to try again; so does this one.
        child: corpus.when(
          loading: ListSkeleton.new,
          error: (error, stack) => ErrorView(
            details: error.toString(),
            onRetry: () => ref.invalidate(corpusProvider),
          ),
          data: (data) => _body(context, data),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, KnowledgeBase corpus) {
    final l10n = AppL10n.of(context);
    final language = ref.watch(activeLanguageProvider);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final terms = corpus.glossaryMatching(query);

    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: ReadingColumn(
              child: TextField(
                controller: _controller,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: ref.read(searchQueryProvider.notifier).set,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchQueryProvider.notifier).clear();
                          },
                        ),
                ),
              ),
            ),
          ),
          if (query.trim().isNotEmpty)
            _CompletionsStrip(onChoose: _completeLastWord),
          Expanded(
            child: switch ((
              query.trim().isEmpty,
              results.isEmpty && terms.isEmpty,
            )) {
              // Before anything is typed the screen used to be a single
              // illustration and two sentences of advice, which is a poster
              // rather than a tool: it told the reader search existed and
              // gave them nothing to press. What replaces it is what they
              // were doing last, and where the corpus itself is densest.
              (true, _) => _SearchInvitation(
                language: language,
                onSearch: _runQuery,
                onOpen: _openResult,
              ),
              (false, true) => EmptyView(
                icon: Icons.search_off,
                title: l10n.searchNoResultsTitle(query),
                body: l10n.searchNoResultsBody,
              ),
              (false, false) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  0,
                  Spacing.lg,
                  Spacing.xxxl,
                ),
                // One row for the count, one for the glossary strip when
                // there is one, then the entries.
                itemCount: results.length + (terms.isEmpty ? 1 : 2),
                separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "No results" above a glossary chip told the reader
                    // there was nothing and then showed them something.
                    // The count is about entries; when there are none but
                    // the word is defined, say that instead.
                    final label = results.isEmpty
                        ? l10n.searchOnlyGlossary
                        : AppNumbers.localizeDigits(
                            l10n.searchResultCount(results.length),
                            language,
                          );
                    return ReadingColumn(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    );
                  }
                  if (terms.isNotEmpty && index == 1) {
                    return ReadingColumn(
                      child: _GlossaryStrip(terms: terms, language: language),
                    );
                  }
                  final hit = results[index - 1 - (terms.isEmpty ? 0 : 1)];
                  final card = EntityCard(
                    title: hit.entity.name.resolve(language),
                    summary: hit.entity.oneLine.resolve(language),
                    // Telling the reader why an apparently unrelated entry
                    // is in the list is the difference between a search
                    // that feels intelligent and one that feels broken.
                    footnote: hit.bestField == MatchField.body
                        ? l10n.searchMatchedInBody
                        : null,
                    onTap: () => _openResult(hit.entity.ref.route),
                  );

                  // Only the first screenful animates in. Items further
                  // down are disposed once they scroll out of range and
                  // would animate again on the way back, which reads as a
                  // glitch rather than as polish.
                  if (index > _animatedResults) {
                    return ReadingColumn(child: card);
                  }

                  return ReadingColumn(
                    child: EntranceAnimation(
                      // Keyed by the query so a new search re-animates
                      // rather than swapping silently under the reader.
                      key: ValueKey<String>('$query-${hit.entity.ref}'),
                      index: index - 1,
                      child: card,
                    ),
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Words the corpus knows that begin with what the reader is typing.
///
/// Sits between the field and the results, where it is visible whether or not
/// the query found anything — a completion is most useful in the case where
/// nothing was found, because the usual reason is that the word is half typed.
class _CompletionsStrip extends ConsumerWidget {
  const _CompletionsStrip({required this.onChoose});

  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completions = ref.watch(searchCompletionsProvider);
    if (completions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      // Named for a screen reader rather than with a visible heading. Chips
      // directly under a search field read as completions to anyone who can
      // see where they are; a reader who cannot gets a row of loose words with
      // no idea what pressing one would do, and a heading here would cost the
      // results a line of a phone screen.
      child: Semantics(
        container: true,
        label: AppL10n.of(context).searchCompletionsTitle,
        // Scrolls rather than wraps: this sits above the results and must not
        // push them off the screen when a common prefix returns eight words.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: <Widget>[
              for (final completion in completions)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Spacing.sm),
                  child: ActionChip(
                    label: Text(completion),
                    labelStyle: theme.textTheme.labelMedium,
                    onPressed: () => onChoose(completion),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the search screen offers before a word has been typed.
///
/// ## Why not the illustration that was here
///
/// An empty state that names the feature and explains how to use it is the
/// right shape for a form a reader has to fill in. A search box is not that:
/// the reader already knows what it does, and what they lack is not
/// instruction but a starting point. The advice about spelling is still worth
/// saying, so it stays — underneath the things that can be pressed rather than
/// in place of them.
class _SearchInvitation extends ConsumerWidget {
  const _SearchInvitation({
    required this.language,
    required this.onSearch,
    required this.onOpen,
  });

  final AppLanguage language;

  /// Runs a query the reader chose from their history.
  final ValueChanged<String> onSearch;

  /// Opens an entry the reader chose directly.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final recent = ref.watch(recentSearchesProvider);
    final startingPoints = ref.watch(searchStartingPointsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        0,
        Spacing.lg,
        Spacing.xxxl,
      ),
      children: <Widget>[
        // The screen's one sentence of voice, kept from the empty state this
        // replaced. Everything under it can be pressed; this says what the
        // pressing is for.
        ReadingColumn(
          alignToStart: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Spacing.lg),
            child: Text(
              l10n.searchInvitationTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        if (recent.isNotEmpty)
          ReadingColumn(
            alignToStart: true,
            child: _Section(
              title: l10n.searchRecentTitle,
              action: TextButton(
                onPressed: () => unawaited(
                  ref.read(recentSearchesProvider.notifier).clear(),
                ),
                child: Text(l10n.searchRecentClear),
              ),
              child: Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: <Widget>[
                  for (final query in recent)
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(query),
                      onPressed: () => onSearch(query),
                    ),
                ],
              ),
            ),
          ),
        if (startingPoints.isNotEmpty)
          ReadingColumn(
            alignToStart: true,
            child: _Section(
              title: l10n.searchStartingPointsTitle,
              child: Column(
                children: <Widget>[
                  for (var index = 0; index < startingPoints.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: EntranceAnimation(
                        index: index,
                        child: EntityCard(
                          title: startingPoints[index].name.resolve(language),
                          summary: startingPoints[index].oneLine.resolve(
                            language,
                          ),
                          onTap: () => onOpen(startingPoints[index].ref.route),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ReadingColumn(
          alignToStart: true,
          child: Padding(
            padding: const EdgeInsets.only(top: Spacing.md),
            child: Text(
              l10n.searchInvitationBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A titled block in the search screen's empty state.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;

  /// An optional control on the far end of the heading.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: Spacing.sm),
          child,
        ],
      ),
    );
  }
}

/// The glossary terms matching the query, above the entries.
///
/// Separate from the results rather than mixed into them: a definition and an
/// entry answer different questions, and interleaving them buries both. A
/// reader searching "dialectic" usually wants to know what the word means
/// before they want a list of everyone who used it.
class _GlossaryStrip extends StatelessWidget {
  const _GlossaryStrip({required this.terms, required this.language});

  final List<GlossaryTerm> terms;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.glossaryTitle,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (final term in terms)
                ActionChip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 16),
                  label: Text(term.term.resolve(language)),
                  onPressed: () => showGlossaryTerm(context, term, language),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
