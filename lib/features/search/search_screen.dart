import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/glossary_sheet.dart';
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = ref.watch(activeLanguageProvider);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final terms =
        ref.watch(corpusProvider).value?.glossaryMatching(query) ??
        const <GlossaryTerm>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LamplightBackdrop(
        intensity: 0.7,
        child: SafeArea(
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
              Expanded(
                child: switch ((
                  query.trim().isEmpty,
                  results.isEmpty && terms.isEmpty,
                )) {
                  (true, _) => EmptyView(
                    icon: Icons.travel_explore,
                    title: l10n.searchInvitationTitle,
                    body: l10n.searchInvitationBody,
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
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Spacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ReadingColumn(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.sm),
                            child: Text(
                              AppNumbers.localizeDigits(
                                l10n.searchResultCount(results.length),
                                language,
                              ),
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
                          child: _GlossaryStrip(
                            terms: terms,
                            language: language,
                          ),
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
                        onTap: () => context.push(hit.entity.ref.route),
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
        ),
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
