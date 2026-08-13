import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
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
    final today = DateTime.now();
    final dayNumber =
        DateTime.utc(
          today.year,
          today.month,
          today.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return shareable[dayNumber % shareable.length];
  }

  /// Four philosophers spread across traditions.
  ///
  /// Deliberately not "the four most famous": a newcomer's first screen is
  /// where a product silently declares whose philosophy counts, so this takes
  /// one from each of several traditions rather than the top of a canon.
  List<Philosopher> get _startingPoints {
    final seen = <String>{};
    final picks = <Philosopher>[];
    for (final philosopher in corpus.philosophers) {
      final tradition = philosopher.traditions.firstOrNull?.id ?? '';
      if (seen.add(tradition)) picks.add(philosopher);
      if (picks.length == 4) break;
    }
    return picks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final quote = _dailyQuote;

    // Entrance order runs top to bottom, so the eye is led down the page in
    // reading order rather than everything arriving at once.
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
                        l10n.appName,
                        style: theme.textTheme.displayMedium?.copyWith(
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      const TitleRule(),
                      const SizedBox(height: Spacing.md),
                      Text(
                        l10n.appTagline,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xxl),

                if (quote != null) ...<Widget>[
                  EntranceAnimation(
                    index: step++,
                    child: SectionHeader(title: l10n.homeDailyIdea),
                  ),
                  EntranceAnimation(
                    index: step++,
                    child: QuoteCard(
                      quote: quote,
                      language: language,
                      speakerName:
                          corpus
                              .philosopher(quote.speakerId)
                              ?.name
                              .resolve(language) ??
                          quote.speakerId,
                      onTapSpeaker: () => context.push(quote.speakerRef.route),
                    ),
                  ),
                  if (quote.context != null)
                    EntranceAnimation(
                      index: step++,
                      child: Padding(
                        padding: const EdgeInsets.only(top: Spacing.md),
                        child: Text(
                          quote.context!.resolve(language),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.xxl),
                ],

                EntranceAnimation(
                  index: step++,
                  child: SectionHeader(
                    title: l10n.homeStartHere,
                    trailing: TextButton.icon(
                      onPressed: () => _surpriseMe(context),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(l10n.homeSurpriseMe),
                    ),
                  ),
                ),
                for (final philosopher in _startingPoints) ...<Widget>[
                  EntranceAnimation(
                    index: step++,
                    child: EntityCard(
                      title: philosopher.name.resolve(language),
                      summary: philosopher.oneLine.resolve(language),
                      meta: AppDates.lifeSpan(philosopher.life, language, l10n),
                      onTap: () => context.push(philosopher.ref.route),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _surpriseMe(BuildContext context) {
    final entities = corpus.allEntities.toList();
    if (entities.isEmpty) return;
    final choice = entities[math.Random().nextInt(entities.length)];
    context.push(choice.ref.route);
  }
}
