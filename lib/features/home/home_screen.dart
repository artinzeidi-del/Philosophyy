import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
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
      body: corpus.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          details: error.toString(),
          onRetry: () => ref.invalidate(corpusProvider),
        ),
        data: (data) => _HomeBody(corpus: data, language: language),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final quote = _dailyQuote;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.xl,
          Spacing.lg,
          Spacing.xxxl,
        ),
        children: <Widget>[
          ReadingColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.appName, style: theme.textTheme.displaySmall),
                const SizedBox(height: Spacing.xs),
                Text(
                  l10n.appTagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.xxl),

                if (quote != null) ...<Widget>[
                  SectionHeader(title: l10n.homeDailyIdea),
                  QuoteCard(
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
                  if (quote.context != null) ...<Widget>[
                    const SizedBox(height: Spacing.md),
                    Text(
                      quote.context!.resolve(language),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.xxl),
                ],

                SectionHeader(
                  title: l10n.homeStartHere,
                  trailing: TextButton.icon(
                    onPressed: () => _surpriseMe(context),
                    icon: const Icon(Icons.casino_outlined, size: 18),
                    label: Text(l10n.homeSurpriseMe),
                  ),
                ),
                for (final philosopher in _startingPoints) ...<Widget>[
                  EntityCard(
                    title: philosopher.name.resolve(language),
                    summary: philosopher.oneLine.resolve(language),
                    meta: AppDates.lifeSpan(philosopher.life, language, l10n),
                    onTap: () => context.push(philosopher.ref.route),
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

  void _surpriseMe(BuildContext context) {
    final entities = corpus.allEntities.toList();
    if (entities.isEmpty) return;
    final choice = entities[math.Random().nextInt(entities.length)];
    context.push(choice.ref.route);
  }
}
