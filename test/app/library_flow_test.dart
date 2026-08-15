import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/stored_user_data_repository.dart';
import 'package:philosophyy/data/user/user_library_codec.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
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

  /// Opens a named entry, rather than whichever card happens to be first.
  ///
  /// The highlight tests need to seed the library before the app is pumped,
  /// which means knowing in advance which article will be open. They used to
  /// assume the home screen's first card is the first record in the content
  /// file; that stopped being true the day the entry points started rotating
  /// by date, and the failure looked like a highlight bug rather than a test
  /// making an assumption it had no right to make.
  Future<void> openEntity(WidgetTester tester, EntityRef ref) async {
    final context = tester.element(find.byType(EntityCard).first);
    unawaited(GoRouter.of(context).push(ref.route));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('Marking a passage', () {
    /// The first section of the article that is actually open, as the reader
    /// sees it.
    ///
    /// Highlights anchor against rendered text, so a test that made up its own
    /// string would prove nothing about the screen. Read from the open article
    /// rather than assumed: this used to hardcode `corpus.philosophers.first`
    /// on the belief that the home screen's first card is the first record in
    /// the file, and that stopped being true the day the entry points started
    /// rotating.
    /// The first quick section of a named entry.
    ({String sectionId, String text}) sectionOf(Philosopher philosopher) {
      final section = philosopher.article.at(ContentDepth.quick).first;
      return (
        sectionId: section.id,
        text: section.body.resolve(AppLanguage.en),
      );
    }

    ({EntityRef ref, String sectionId, String text}) openArticle(
      WidgetTester tester,
    ) {
      final view = tester.widget<ArticleView>(find.byType(ArticleView).first);
      final section = view.article.at(ContentDepth.quick).first;
      final entity = corpus.philosophers.firstWhere(
        (candidate) => candidate.article == view.article,
        orElse: () => corpus.philosophers.first,
      );
      return (
        ref: entity.ref,
        sectionId: section.id,
        text: section.body.resolve(AppLanguage.en),
      );
    }

    testWidgets('a marked passage is stored, shown, and reaches the library', (
      tester,
    ) async {
      final store = await pumpApp(tester);
      await openFirstArticle(tester);

      final section = openArticle(tester);
      final excerpt = section.text.substring(0, 20);

      // Driven through the provider rather than through the selection toolbar:
      // the toolbar is platform-drawn and cannot be tapped in a widget test,
      // but everything after it — storage, re-anchoring, rendering, the library
      // — is the product's own code and is what can actually break.
      final context = tester.element(find.byType(ArticleView).first);
      await ProviderScope.containerOf(context)
          .read(libraryProvider.notifier)
          .addHighlight(
            target: section.ref,
            sectionId: section.sectionId,
            start: 0,
            end: 20,
            excerpt: excerpt,
          );
      await tester.pumpAndSettle();

      expect(stored(store).highlights, hasLength(1));

      // The passage is painted in the article, as its own span.
      final body = tester.widget<SelectableText>(
        find.byType(SelectableText).first,
      );
      final spans = (body.textSpan!.children ?? const <InlineSpan>[])
          .whereType<TextSpan>()
          .toList();
      expect(
        spans.any((span) => span.text == excerpt && span.style != null),
        isTrue,
        reason: 'the marked run was not painted differently from the rest',
      );

      // And the reader can find it again from the library.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.navLibrary);
      expect(find.text(en.libraryHighlightsSection), findsOneWidget);
      expect(find.textContaining(excerpt), findsWidgets);
    });

    testWidgets('a passage that moved is found again, not lost', (
      tester,
    ) async {
      // The reason a highlight stores its excerpt as well as its offsets:
      // content is edited between releases, and painting a stale range would
      // put the reader's mark on a sentence they never marked.
      final subject = corpus.philosophers.first;
      final section = sectionOf(subject);
      final excerpt = section.text.substring(10, 30);
      final ref = subject.ref;

      await pumpApp(
        tester,
        initial: UserLibrary.empty.withHighlight(
          Highlight(
            id: 'stale',
            target: ref,
            sectionId: section.sectionId,
            // Deliberately wrong: where the passage used to be.
            start: 0,
            end: 20,
            excerpt: excerpt,
            createdAt: DateTime.utc(2024),
          ),
        ),
      );
      await openEntity(tester, ref);

      final body = tester.widget<SelectableText>(
        find.byType(SelectableText).first,
      );
      final spans = (body.textSpan!.children ?? const <InlineSpan>[])
          .whereType<TextSpan>()
          .toList();
      final marked = spans.where((span) => span.style != null).toList();
      expect(marked, hasLength(1));
      expect(
        marked.single.text,
        excerpt,
        reason:
            'the mark was painted at the stale offsets instead of being '
            're-anchored to the text it actually covered',
      );
    });

    testWidgets('a passage that is gone is not painted anywhere', (
      tester,
    ) async {
      // Losing the mark is the right outcome when the passage no longer exists.
      // Guessing at a location would be worse than admitting it is gone.
      final subject = corpus.philosophers.first;
      final section = sectionOf(subject);
      final ref = subject.ref;

      await pumpApp(
        tester,
        initial: UserLibrary.empty.withHighlight(
          Highlight(
            id: 'vanished',
            target: ref,
            sectionId: section.sectionId,
            start: 0,
            end: 20,
            excerpt: 'a sentence this article has never contained',
            createdAt: DateTime.utc(2024),
          ),
        ),
      );
      await openEntity(tester, ref);

      final body = tester.widget<SelectableText>(
        find.byType(SelectableText).first,
      );
      final spans = (body.textSpan!.children ?? const <InlineSpan>[])
          .whereType<TextSpan>()
          .toList();
      expect(spans.where((span) => span.style != null), isEmpty);

      // But it is still the reader's, and still listed — under its own
      // heading, with the explanation. It used to sit among the live marks,
      // so a reader tapped it, arrived at an article with nothing marked, and
      // was told nothing. The copy for this had been written and never shown.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.navLibrary);
      expect(find.text(en.highlightLostTitle), findsOneWidget);
      expect(find.text(en.highlightLostBody), findsOneWidget);
      expect(
        find.text('a sentence this article has never contained'),
        findsOneWidget,
      );
      // And it is not claimed to be live.
      expect(find.text(en.libraryHighlightsSection), findsNothing);
    });

    testWidgets('removing a mark takes it off the page and off disk', (
      tester,
    ) async {
      final subject = corpus.philosophers.first;
      final section = sectionOf(subject);
      final ref = subject.ref;
      final store = await pumpApp(
        tester,
        initial: UserLibrary.empty.withHighlight(
          Highlight(
            id: 'to-remove',
            target: ref,
            sectionId: section.sectionId,
            start: 0,
            end: 20,
            excerpt: section.text.substring(0, 20),
            createdAt: DateTime.utc(2024),
          ),
        ),
      );
      await openEntity(tester, ref);

      final context = tester.element(find.byType(ArticleView).first);
      await ProviderScope.containerOf(context)
          .read(libraryProvider.notifier)
          .removeHighlight('to-remove');
      await tester.pumpAndSettle();

      expect(stored(store).highlights, isEmpty);
      final body = tester.widget<SelectableText>(
        find.byType(SelectableText).first,
      );
      final spans = (body.textSpan!.children ?? const <InlineSpan>[])
          .whereType<TextSpan>()
          .toList();
      expect(spans.where((span) => span.style != null), isEmpty);
    });
  });

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
