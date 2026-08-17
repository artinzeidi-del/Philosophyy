import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/responsive.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/core/search/text_normalizer.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/features/shared/skeletons.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The glossary: every word in the product a reader might not know.
///
/// ## Why it is a screen and not only a popover
///
/// The popover answers a question the reader already has. This screen answers
/// one they do not know to ask — what vocabulary does this subject expect of
/// me — and it is the difference between a product that assumes you can read
/// philosophy and one that will teach you to.
class GlossaryScreen extends ConsumerStatefulWidget {
  const GlossaryScreen({this.initialTermId, super.key});

  /// A term to scroll to and open on arrival, when linked to from a definition.
  final String? initialTermId;

  @override
  ConsumerState<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends ConsumerState<GlossaryScreen> {
  String _query = '';

  /// How far down the list the staggered arrival runs.
  ///
  /// A screenful, not the whole list: beyond that the items are built as the
  /// reader scrolls to them, and animating on build means they animate again
  /// every time they scroll back into range.
  static const int _animatedTerms = 8;

  @override
  Widget build(BuildContext context) {
    final corpus = ref.watch(corpusProvider);
    final language = ref.watch(activeLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The body paints the canvas, so the bar has to sit *on* it. Without
      // this the bar is a transparent strip over whatever is behind the
      // route — which is white — and the title vanished into it.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppL10n.of(context).glossaryTitle),
        backgroundColor: Colors.transparent,
      ),
      body: LamplightBackdrop(
        intensity: 0.6,
        child: corpus.when(
          loading: ListSkeleton.new,
          error: (error, stack) => ErrorView(
            details: error.toString(),
            onRetry: () => ref.invalidate(corpusProvider),
          ),
          data: (data) => _body(context, data.glossary, language),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<GlossaryTerm> glossary,
    AppLanguage language,
  ) {
    final l10n = AppL10n.of(context);

    // Matching goes through the same normaliser search uses, so a Persian
    // reader typing without the zero-width non-joiner still finds the word.
    // Sorted by the language on screen. The list arrives alphabetical by
    // English, which puts «آپوریا» between «زیبایی‌شناسی» and «پیکرهٔ متعارف»
    // for a Persian reader — an order with no relation to the words they are
    // looking at, in the language the product says it favours.
    final ordered = <GlossaryTerm>[...glossary]
      ..sort(
        (a, b) => a.term
            .resolve(language)
            .toLowerCase()
            .compareTo(b.term.resolve(language).toLowerCase()),
      );

    // A term arrived at by link goes to the head of the list.
    //
    // Scrolling to it was the first attempt and it does not work: the list is
    // lazy, so the card does not exist to be scrolled to, and the reader
    // landed at the top with the word they asked about expanded somewhere
    // below the fold — which looks exactly like a link that did nothing.
    // Putting it first needs no machinery and is what the reader asked for.
    final linked = widget.initialTermId;
    if (linked != null) {
      final index = ordered.indexWhere((term) => term.id == linked);
      if (index > 0) ordered.insert(0, ordered.removeAt(index));
    }

    final needle = TextNormalizer.normalize(_query);
    final terms = needle.isEmpty
        ? ordered
        : ordered.where((term) {
            final haystack = <String>[
              term.term.en,
              ?term.term.fa,
              ?term.nativeTerm,
              ?term.transliteration,
              term.shortDefinition.en,
              ?term.shortDefinition.fa,
              ...term.aliases,
            ].map(TextNormalizer.normalize).join(' ');
            return haystack.contains(needle);
          }).toList();

    return SafeArea(
      child: ContentColumn(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              // `Spacing.md`, not `kToolbarHeight + Spacing.md`. A
              // `Scaffold` with `extendBodyBehindAppBar` adds the bar's
              // height to the body's own top padding, so the `SafeArea`
              // above already clears it — adding it again put 56 pixels of
              // nothing between the title and the first line.
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.gutterFor(context),
                Spacing.md,
                ResponsiveLayout.gutterFor(context),
                Spacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.glossaryIntro,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.glossarySearchHint,
                        border: const OutlineInputBorder(
                          borderRadius: Radii.cardRadius,
                        ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ],
                ),
              ),
            ),
            if (terms.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xxl),
                  child: Text(
                    l10n.searchNoResultsBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.gutterFor(context),
                ),
                sliver: SliverList.builder(
                  itemCount: terms.length,
                  itemBuilder: (context, index) {
                    final card = Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: _TermCard(
                        term: terms[index],
                        language: language,
                        startExpanded: terms[index].id == widget.initialTermId,
                      ),
                    );

                    // Only the first screenful arrives. Items further down are
                    // disposed when they scroll out of range and would animate
                    // again on the way back, which reads as a glitch rather
                    // than as polish — the same rule the search results use.
                    if (index > _animatedTerms) return card;

                    return EntranceAnimation(
                      // Keyed by the filter so narrowing the list re-animates
                      // rather than swapping silently under the reader.
                      key: ValueKey<String>('$_query-${terms[index].id}'),
                      index: index,
                      child: card,
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxxl)),
          ],
        ),
      ),
    );
  }
}

/// One term, with its long definition behind a tap.
///
/// Collapsed by default: fifty terms each showing a paragraph is a wall, and
/// the reader scanning for one word should be able to see the list.
class _TermCard extends StatefulWidget {
  const _TermCard({
    required this.term,
    required this.language,
    this.startExpanded = false,
  });

  final GlossaryTerm term;
  final AppLanguage language;
  final bool startExpanded;

  @override
  State<_TermCard> createState() => _TermCardState();
}

class _TermCardState extends State<_TermCard> {
  late bool _expanded = widget.startExpanded;

  /// Whether two strings would look the same to a reader.
  ///
  /// Arabic-script text carries several pairs of code points that render
  /// alike — Arabic yeh against Persian yeh, Arabic kaf against keheh — and a
  /// byte comparison treats them as different words. The search normaliser
  /// already folds exactly these, so it is the right authority here too.
  static bool _looksLike(String a, String? b) =>
      b != null && TextNormalizer.normalize(a) == TextNormalizer.normalize(b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final term = widget.term;
    final language = widget.language;
    final long = term.longDefinition;
    final native = term.nativeTerm;
    final conceptId = term.conceptId;
    final canExpand = long != null || conceptId != null;

    // `PressableSurface` rather than a bare `Material` + `InkWell`: every other
    // card in the app dips slightly under the finger, and a glossary card that
    // only ripples felt like a different product's list.
    return PressableSurface(
      onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      borderRadius: Radii.surfaceRadius,
      decoration: BoxDecoration(
        color: Glass.fill(context),
        borderRadius: Radii.surfaceRadius,
        border: Border.all(color: Glass.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    term.term.resolve(language),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                // The other language, always visible. A bilingual glossary
                // whose Persian reader cannot see the English word is only
                // half a glossary: the English is what they will meet in a
                // paper or a search box.
                // Flexible: at 1.5x a Persian term and its English beside it
                // ran 46 pixels off the card, and the second word had no
                // flex to give.
                Flexible(
                  child: Text(
                    language == AppLanguage.fa
                        ? term.term.en
                        : term.term.fa ?? '',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            // Not shown when it repeats a word already on the card. The
            // header prints both languages, so the check covers both — and
            // it compares them the way a reader sees them rather than byte
            // for byte. «قیاس» and «قياس» differ only in which yeh they use,
            // Persian against Arabic, and printing both put what looks like
            // the same word on the card twice.
            if (native != null &&
                !_looksLike(native, term.term.en) &&
                !_looksLike(native, term.term.fa)) ...<Widget>[
              const SizedBox(height: Spacing.xxs),
              Text(
                native,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: Spacing.sm),
            Text(
              term.shortDefinition.resolve(language),
              style: AppTypography.reading(
                term.shortDefinition.resolvedLanguage(language),
              ).copyWith(color: theme.colorScheme.onSurface),
            ),
            AnimatedCrossFade(
              duration: MotionTokens.quick,
              sizeCurve: MotionTokens.standard,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (long != null) ...<Widget>[
                    const SizedBox(height: Spacing.md),
                    Text(
                      long.resolve(language),
                      style: AppTypography.reading(
                        long.resolvedLanguage(language),
                      ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (conceptId != null) ...<Widget>[
                    const SizedBox(height: Spacing.md),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.push(
                          EntityRef(EntityKind.concept, conceptId).route,
                        ),
                        icon: const Icon(Icons.article_outlined, size: 18),
                        label: Text(l10n.glossaryOpenEntry),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
