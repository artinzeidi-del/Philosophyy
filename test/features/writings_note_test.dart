import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An absent work has to be distinguishable from an absent entry.
///
/// ## The defect this is written against
///
/// The philosopher screen used to drop the works section whenever a person had
/// no works in the corpus. For a hundred and eighty entries that is correct.
/// For Socrates, who wrote nothing on principle, and for Hypatia, whose
/// commentaries were destroyed, it produced a page indistinguishable from one
/// nobody had finished filling in — and the reason there is nothing to read is
/// among the most important things a reference can say about either of them.
///
/// So the corpus records what became of each person's writing, and the screen
/// says it. These tests check that the record is honest, that the note is
/// shown, and that it does not appear over the hundreds of entries where works
/// really are there to read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  group('The record', () {
    test('nobody marked as having no writing has a work in the corpus', () {
      // The two halves must not contradict each other: a page that shows a
      // work and a note saying no work survives is worse than either alone.
      final offenders = <String>[
        for (final philosopher in corpus.philosophers)
          if (philosopher.writings == Writings.none &&
              corpus.worksBy(philosopher.id).isNotEmpty)
            philosopher.id,
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'these entries say nothing of theirs survives and then list '
            'something of theirs: $offenders',
      );
    });

    test('everyone marked as fragments has exactly the fragments', () {
      // The other direction. A fragments note with no collection beside it
      // leaves the reader with nothing at all to open, which is a worse page
      // than the one this replaced — except for Protagoras, where the surviving
      // sentences are too few to gather into an entry of their own.
      for (final philosopher in corpus.philosophers) {
        if (philosopher.writings != Writings.fragments) continue;
        if (philosopher.id == 'protagoras') continue;
        expect(
          corpus.worksBy(philosopher.id),
          isNotEmpty,
          reason:
              '${philosopher.id} is marked as surviving in fragments and has '
              'no collection of them to open',
        );
      }
    });

    test('the ordinary case is untouched', () {
      // A guard against the field being applied enthusiastically. The vast
      // majority of the corpus wrote books that exist.
      final extant = corpus.philosophers
          .where((p) => p.writings == Writings.extant)
          .length;
      expect(extant, greaterThan(corpus.philosophers.length * 0.8));
    });

    test('every philosopher with no work is accounted for', () {
      // The point of the whole exercise: no entry may be silently empty. If a
      // philosopher has no work in the corpus, either we say why, or the
      // corpus is missing something and this test is the reminder.
      final unexplained = <String>[
        for (final philosopher in corpus.philosophers)
          if (philosopher.writings == Writings.extant &&
              corpus.worksBy(philosopher.id).isEmpty)
            philosopher.id,
      ];
      expect(
        unexplained,
        isEmpty,
        reason:
            'these philosophers have no work and no explanation for it, so '
            'their page shows an unexplained gap: $unexplained',
      );
    });
  });

  group('The page', () {
    Future<void> open(WidgetTester tester, String id) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final store = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(PreferencesStore(store)),
            corpusProvider.overrideWith((ref) => corpus),
            initialLibraryProvider.overrideWithValue(UserLibrary.empty),
            initialRouteProvider.overrideWithValue('/philosophers/$id'),
          ],
          child: const PhilosophiaApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('says so on the page of someone who wrote nothing', (
      tester,
    ) async {
      await open(tester, 'socrates');
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(find.text(l10n.sectionWorks), findsOneWidget);
      expect(find.text(l10n.writingsNone), findsOneWidget);
    });

    testWidgets('says so for someone who survives only in quotation', (
      tester,
    ) async {
      await open(tester, 'heraclitus');
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(find.text(l10n.writingsFragments), findsOneWidget);
      // And the collection is still offered, so the note explains the entry
      // rather than replacing it.
      expect(find.text(l10n.sectionWorks), findsOneWidget);
    });

    testWidgets('stays quiet where the books exist', (tester) async {
      await open(tester, 'plato');
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(find.text(l10n.sectionWorks), findsOneWidget);
      expect(find.text(l10n.writingsNone), findsNothing);
      expect(find.text(l10n.writingsFragments), findsNothing);
    });
  });
}
