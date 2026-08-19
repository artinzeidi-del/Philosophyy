import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// A quotation the reader cannot trace is a claim, not a citation.
///
/// The corpus has always recorded, for every verified quotation, the text it
/// comes from and the place in it. The card that displays quotations read none
/// of that: it showed the words, the speaker, and a badge saying «تأییدشده»,
/// and gave the reader nothing to check it against. Nothing failed — no
/// analyzer warning, no layout problem, no missing asset — because a field
/// that is never read is invisible to every check that looks at what is
/// rendered.
///
/// So this looks the other way round: it starts from what the corpus knows and
/// asserts the screen says it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpCard(
    WidgetTester tester,
    Widget card,
    AppLanguage language,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language.code),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in AppLanguage.values) {
    testWidgets('a cited quotation names its source in ${language.code}', (
      tester,
    ) async {
      final quote = corpus.quotes.firstWhere(
        (quote) => quote.citation?.locator != null,
      );
      final source = corpus.source(quote.citation!.sourceId)!;

      await pumpCard(
        tester,
        QuoteCard(
          quote: quote,
          language: language,
          speakerName: 'x',
          resolveSource: corpus.source,
        ),
        language,
      );

      expect(
        find.textContaining(source.title.resolve(language)),
        findsOneWidget,
        reason: 'the card does not say which text the words are from',
      );
      expect(
        find.textContaining(quote.citation!.locator!),
        findsOneWidget,
        reason: 'the card does not say where in the text to look',
      );
    });
  }

  testWidgets('an uncited quotation adds no empty line', (tester) async {
    // The other half of the rule: a card that renders a separator, an icon and
    // nothing else is worse than one that renders neither, because it reads as
    // a source that failed to load.
    final quote = corpus.quotes.firstWhere((quote) => quote.citation == null);

    await pumpCard(
      tester,
      QuoteCard(
        quote: quote,
        language: AppLanguage.fa,
        speakerName: 'x',
        resolveSource: corpus.source,
      ),
      AppLanguage.fa,
    );

    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
  });

  test('every quotation claiming verification can be traced', () {
    // The editorial rule, checked against the corpus rather than against the
    // screen. `Quote.isPublishable` states it; this is what makes a breach
    // fail rather than merely be inconsistent with the doc comment.
    final untraceable = <String>[
      for (final quote in corpus.quotes)
        if (quote.attribution == AttributionStatus.verified)
          if (quote.citation == null)
            '${quote.id}: verified with no citation'
          else if (corpus.source(quote.citation!.sourceId) == null)
            '${quote.id}: cites a source not in the corpus',
    ];

    expect(untraceable, isEmpty, reason: untraceable.join('\n'));
  });
}
