import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/stored_user_data_repository.dart';
import 'package:philosophyy/data/user/user_library_codec.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives saving and note-taking through the real interface.
///
/// The repository tests prove the data survives. These prove the reader can
/// actually get to it: that the button is reachable, that what it saves shows up
/// on the library screen, and that it is on disk afterwards rather than only in
/// memory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late AppL10n en;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    en = await AppL10n.delegate.load(const Locale('en'));
  });

  /// Boots the app on a viewport tall enough to avoid scrolling.
  Future<InMemoryStore> pumpApp(
    WidgetTester tester, {
    UserLibrary initial = UserLibrary.empty,
  }) async {
    tester.view.physicalSize = const Size(1100, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = InMemoryStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          userDataRepositoryProvider.overrideWithValue(
            StoredUserDataRepository(store),
          ),
          initialLibraryProvider.overrideWithValue(initial),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  /// The library as it exists on disk.
  UserLibrary stored(InMemoryStore store) {
    final raw = store.read(StoredUserDataRepository.libraryKey);
    return raw == null ? UserLibrary.empty : UserLibraryCodec.decode(raw);
  }

  Future<void> openFirstArticle(WidgetTester tester) async {
    await tester.tap(find.byType(EntityCard).first);
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('Saving an entry', () {
    testWidgets('the button saves it, and the library shows it', (
      tester,
    ) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);

      // The article opens unsaved.
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      // The button reflects the new state.
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      // And it is on disk, not merely on screen.
      expect(stored(store).bookmarks, hasLength(1));

      // The reader can find it again.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.navLibrary);

      expect(find.text(en.librarySavedSection), findsOneWidget);
      expect(find.byType(EntityCard), findsWidgets);
    });

    testWidgets('tapping again removes it', (tester) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(stored(store).bookmarks, isEmpty);
    });
  });

  group('Writing a note', () {
    testWidgets('it is composed, saved, and listed on the article', (
      tester,
    ) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);

      await tester.tap(find.text(en.noteAdd));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'Worth rereading before the seminar.',
      );
      await tester.tap(find.text(en.noteSave));
      await tester.pumpAndSettle();

      // Shown on the article.
      expect(find.text('Worth rereading before the seminar.'), findsOneWidget);
      // And persisted.
      expect(
        stored(store).notes.single.body,
        'Worth rereading before the seminar.',
      );
    });

    testWidgets('cancelling writes nothing', (tester) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);

      await tester.tap(find.text(en.noteAdd));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'a false start');
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(find.text('a false start'), findsNothing);
      expect(stored(store).notes, isEmpty);
    });

    testWidgets('a note can be deleted again', (tester) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);

      await tester.tap(find.text(en.noteAdd));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'temporary');
      await tester.tap(find.text(en.noteSave));
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.noteDelete));
      await tester.pumpAndSettle();

      expect(find.text('temporary'), findsNothing);
      expect(stored(store).notes, isEmpty);
    });
  });

  group('The library screen', () {
    testWidgets('invites the reader in when there is nothing saved', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTab(tester, en.navLibrary);

      expect(find.text(en.libraryEmptyTitle), findsOneWidget);
      expect(find.text(en.libraryEmptyBody), findsOneWidget);
    });

    testWidgets('shows an annotated article even when it was never saved', (
      tester,
    ) async {
      // A reader who wrote a note without bookmarking still expects to find the
      // article again.
      const plato = EntityRef(EntityKind.philosopher, 'plato');
      final now = DateTime.now();
      await pumpApp(
        tester,
        initial: UserLibrary(
          notes: <Note>[
            Note(
              id: 'n1',
              target: plato,
              body: 'the cave is about education',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await openTab(tester, en.navLibrary);

      expect(find.text(en.libraryNotesSection), findsOneWidget);
      expect(find.text('the cave is about education'), findsOneWidget);
      expect(find.text('Plato'), findsWidgets);
    });

    testWidgets('a saved entry that has left the corpus is not hidden', (
      tester,
    ) async {
      // Silently dropping it would look to the reader like their bookmark
      // vanished.
      await pumpApp(
        tester,
        initial: UserLibrary(
          bookmarks: <Bookmark>[
            Bookmark(
              target: const EntityRef(EntityKind.philosopher, 'gone-away'),
              savedAt: DateTime.now(),
            ),
          ],
        ),
      );

      await openTab(tester, en.navLibrary);

      expect(find.text(en.notFoundTitle), findsOneWidget);
    });
  });

  group('Deleting everything', () {
    testWidgets('asks first, then leaves nothing behind', (tester) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(stored(store).bookmarks, hasLength(1));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.navSettings);

      await tester.tap(find.text(en.clearLibrary));
      await tester.pumpAndSettle();

      // The reader is asked before anything is destroyed.
      expect(find.text(en.clearLibraryConfirm), findsOneWidget);
      await tester.tap(find.text(en.clearLibraryConfirm));
      await tester.pumpAndSettle();

      expect(store.keys(), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling keeps the reader\'s work', (tester) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.navSettings);
      await tester.tap(find.text(en.clearLibrary));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(stored(store).bookmarks, hasLength(1));
    });
  });
}
