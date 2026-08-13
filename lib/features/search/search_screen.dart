import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
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
                child: switch ((query.trim().isEmpty, results.isEmpty)) {
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
                    itemCount: results.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Spacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ReadingColumn(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.sm),
                            child: Text(
                              l10n.searchResultCount(results.length),
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
                      final hit = results[index - 1];
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
