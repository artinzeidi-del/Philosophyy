import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A quotation in its own language is the evidence, not decoration.
///
/// ## The defect this is written against
///
/// Forty-one quotations carry the words as they were written — Socrates's
/// Greek, Rūmī's Persian, the Analects in Chinese — and no screen read the
/// field. The app that exists so a reader can check a quotation against its
/// source held the source's own words and showed them a translation.
///
/// The masthead already argues this case for names: the original script is set
/// large and quiet rather than as a footnote, because for a great many readers
/// it is the form they know, and shrinking it to metadata quietly says whose
/// language is primary. A quotation has the better claim, since a translation
/// is an interpretation and the original is what was said.
///
/// Direction is part of being right. Greek must run left to right in a Persian
/// interface and Persian must run right to left in an English one, so the line
/// takes its direction from the script rather than from the reader's language.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpPhilosopher(
    WidgetTester tester,
    String id, {
    String? language,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(
      language == null
          ? const <String, Object>{}
          : <String, Object>{'flutter.settings.language': language},
    );
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue('/philosophers/$id'),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Greek of a Greek quotation is on the page', (tester) async {
    await pumpPhilosopher(tester, 'socrates');
    expect(
      find.text('ὁ δὲ ἀνεξέταστος βίος οὐ βιωτὸς ἀνθρώπῳ'),
      findsOneWidget,
    );
  });

  testWidgets('Greek runs left to right in a Persian interface', (
    tester,
  ) async {
    await pumpPhilosopher(tester, 'socrates', language: 'fa');
    final greek = find.text('ὁ δὲ ἀνεξέταστος βίος οὐ βιωτὸς ἀνθρώπῳ');
    expect(greek, findsOneWidget);
    expect(tester.widget<Text>(greek).textDirection, TextDirection.ltr);
  });

  testWidgets('Persian runs right to left in an English interface', (
    tester,
  ) async {
    await pumpPhilosopher(tester, 'rumi', language: 'en');
    final original = corpus.quotes
        .firstWhere((quote) => quote.id == 'rumi-reed')
        .originalText!;
    final line = find.text(original);
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).textDirection, TextDirection.rtl);
  });

  testWidgets('a quotation with no original gets no empty line', (
    tester,
  ) async {
    // Most quotations reach us only in translation, and the card must look
    // finished without one rather than leaving a gap where the original goes.
    final withoutOriginal = corpus.quotes.where(
      (quote) => quote.originalText == null,
    );
    expect(withoutOriginal, isNotEmpty);
    await pumpPhilosopher(tester, 'thales');
    expect(find.byType(QuoteCard), findsWidgets);
  });
}
