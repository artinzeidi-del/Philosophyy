import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/stored_user_data_repository.dart';
import 'package:philosophyy/data/user/user_library_codec.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reader's own writing is the only data in this product that cannot be
/// regenerated. The corpus ships in the binary; a note does not. These tests are
/// therefore weighted toward the ways it could be lost rather than the way it is
/// normally saved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const plato = EntityRef(EntityKind.philosopher, 'plato');
  const forms = EntityRef(EntityKind.concept, 'theory-of-forms');
  final when = DateTime.utc(2026, 3, 14, 9, 30);

  UserLibrary populated() => UserLibrary(
    bookmarks: <Bookmark>[Bookmark(target: plato, savedAt: when)],
    notes: <Note>[
      Note(
        id: 'note-1',
        target: plato,
        sectionId: 'cave',
        body: 'The prisoners are us — that is the uncomfortable part.',
        createdAt: when,
        updatedAt: when.add(const Duration(hours: 2)),
      ),
      Note(
        id: 'note-2',
        target: forms,
        body: 'یادداشتی به فارسی، برای آزمودن نگهداری متن غیرلاتین.',
        createdAt: when,
        updatedAt: when,
      ),
    ],
    highlights: <Highlight>[
      Highlight(
        id: 'highlight-1',
        target: plato,
        sectionId: 'cave',
        start: 4,
        end: 13,
        excerpt: 'prisoners',
        createdAt: when,
      ),
    ],
    positions: <ReadingPosition>[
      ReadingPosition(
        target: plato,
        sectionId: 'cave',
        scrollOffset: 842.5,
        updatedAt: when,
      ),
    ],
  );

  group('Round-tripping', () {
    test('a full library survives being written and read back', () {
      final restored = UserLibraryCodec.decode(
        UserLibraryCodec.encode(populated()),
      );

      expect(restored.bookmarks.single.target, plato);
      expect(restored.notes.length, 2);
      expect(restored.highlights.single.excerpt, 'prisoners');
      expect(restored.positions.single.scrollOffset, 842.5);
    });

    test('note text survives exactly, including Persian', () {
      final restored = UserLibraryCodec.decode(
        UserLibraryCodec.encode(populated()),
      );
      final persian = restored.notes.firstWhere((note) => note.id == 'note-2');
      expect(
        persian.body,
        'یادداشتی به فارسی، برای آزمودن نگهداری متن غیرلاتین.',
      );
    });

    test('timestamps survive to the second', () {
      final restored = UserLibraryCodec.decode(
        UserLibraryCodec.encode(populated()),
      );
      expect(restored.bookmarks.single.savedAt.toUtc(), when);
    });

    test('an empty library round-trips to an empty library', () {
      final restored = UserLibraryCodec.decode(
        UserLibraryCodec.encode(UserLibrary.empty),
      );
      expect(restored.isEmpty, isTrue);
    });

    test('the document records the schema version it was written with', () {
      final document = jsonDecode(
        UserLibraryCodec.encode(populated()),
      ) as Map<String, Object?>;
      expect(document['version'], UserLibraryCodec.currentVersion);
    });
  });

  group('Refusing to guess', () {
    test('a document from a newer version is refused, not half-read', () {
      // Reading a future schema on a hopeful basis and then saving the result
      // would destroy whatever the newer fields meant.
      final future = jsonEncode(<String, Object?>{
        'version': UserLibraryCodec.currentVersion + 1,
        'bookmarks': <Object?>[],
      });
      expect(
        () => UserLibraryCodec.decode(future),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('a document with no version is refused', () {
      expect(
        () => UserLibraryCodec.decode('{"bookmarks": []}'),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('a version 1 library survives the upgrade with everything intact', () {
      // The codec's own rule: every migration step comes with a test that
      // carries a populated document forward and asserts nothing was lost.
      // This is the reader's own writing — an app update losing it is not an
      // acceptable outcome, and "the migration looked right" is not evidence.
      final version1 = jsonEncode(<String, Object?>{
        'version': 1,
        'bookmarks': <Object?>[
          <String, Object?>{
            'target': 'philosopher:plato',
            'savedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        'notes': <Object?>[
          <String, Object?>{
            'id': 'n1',
            'target': 'concept:justice',
            'sectionId': 's2',
            'body': 'یادداشتی که نباید گم شود',
            'createdAt': '2026-01-02T00:00:00.000Z',
            'updatedAt': '2026-01-03T00:00:00.000Z',
          },
        ],
        'highlights': <Object?>[
          <String, Object?>{
            'id': 'h1',
            'target': 'philosopher:plato',
            'sectionId': 's1',
            'start': 4,
            'end': 10,
            'excerpt': 'justice',
            'createdAt': '2026-01-04T00:00:00.000Z',
          },
        ],
        'positions': <Object?>[
          <String, Object?>{
            'target': 'philosopher:plato',
            'sectionId': 's1',
            'scrollOffset': 640.0,
            'updatedAt': '2026-01-05T00:00:00.000Z',
          },
        ],
      });

      final library = UserLibraryCodec.decode(version1);

      expect(library.bookmarks, hasLength(1));
      expect(library.notes.single.body, 'یادداشتی که نباید گم شود');
      expect(library.notes.single.sectionId, 's2');
      expect(library.highlights.single.excerpt, 'justice');
      expect(library.highlights.single.start, 4);
      expect(library.positions.single.scrollOffset, 640.0);

      // The one thing version 1 could not carry.
      expect(library.readMarks, isEmpty);

      // And the upgraded document is what this build now writes.
      final rewritten =
          jsonDecode(UserLibraryCodec.encode(library)) as Map<String, Object?>;
      expect(rewritten['version'], UserLibraryCodec.currentVersion);
      expect(rewritten['readMarks'], isEmpty);
    });

    test('a version 2 library survives the upgrade with everything intact', () {
      // The codec's rule again, for the step that added the facts a reader has
      // answered. Their notes, marks and positions must come through untouched.
      final version2 = jsonEncode(<String, Object?>{
        'version': 2,
        'bookmarks': <Object?>[
          <String, Object?>{
            'target': 'philosopher:plato',
            'savedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        'notes': <Object?>[
          <String, Object?>{
            'id': 'n1',
            'target': 'concept:justice',
            'body': 'یادداشتی که نباید گم شود',
            'createdAt': '2026-01-02T00:00:00.000Z',
            'updatedAt': '2026-01-03T00:00:00.000Z',
          },
        ],
        'highlights': const <Object?>[],
        'positions': const <Object?>[],
        'readMarks': <Object?>[
          <String, Object?>{
            'target': 'philosopher:plato',
            'markedAt': '2026-01-05T00:00:00.000Z',
          },
        ],
      });

      final library = UserLibraryCodec.decode(version2);

      expect(library.bookmarks, hasLength(1));
      expect(library.notes.single.body, 'یادداشتی که نباید گم شود');
      expect(library.readMarks, hasLength(1));
      expect(library.hasRead(plato), isTrue);

      // The one thing version 2 could not carry.
      expect(library.masteredFacts, isEmpty);

      final rewritten =
          jsonDecode(UserLibraryCodec.encode(library)) as Map<String, Object?>;
      expect(rewritten['version'], UserLibraryCodec.currentVersion);
      expect(rewritten['masteredFacts'], isEmpty);
    });

    test('mastered facts survive a round trip', () {
      final library = UserLibrary.empty.withMastered(const <String>[
        'tradition:plato',
        'author:republic',
      ]);

      final restored = UserLibraryCodec.decode(
        UserLibraryCodec.encode(library),
      );

      expect(restored.masteredFacts, <String>{
        'author:republic',
        'tradition:plato',
      });
    });

    test('a mastered list holding something that is not a fact is refused', () {
      final broken = jsonEncode(<String, Object?>{
        'version': 3,
        'masteredFacts': <Object?>[
          'tradition:plato',
          <String, Object?>{'not': 'a string'},
        ],
      });
      expect(
        () => UserLibraryCodec.decode(broken),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('read marks survive a round trip', () {
      final library = UserLibrary.empty.toggleRead(
        plato,
        at: DateTime.utc(2026, 5, 1),
      );

      final restored = UserLibraryCodec.decode(
        UserLibraryCodec.encode(library),
      );

      expect(restored.hasRead(plato), isTrue);
      expect(restored.readMarks.single.markedAt, DateTime.utc(2026, 5, 1));
    });

    test('malformed JSON is refused', () {
      expect(
        () => UserLibraryCodec.decode('{not json'),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('a reference that no longer parses is refused', () {
      final broken = jsonEncode(<String, Object?>{
        'version': 1,
        'bookmarks': <Object?>[
          <String, Object?>{
            'target': 'nonsense',
            'savedAt': '2026-01-01T00:00:00Z',
          },
        ],
      });
      expect(
        () => UserLibraryCodec.decode(broken),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('an impossible highlight span is refused', () {
      final broken = jsonEncode(<String, Object?>{
        'version': 1,
        'highlights': <Object?>[
          <String, Object?>{
            'id': 'h',
            'target': 'philosopher:plato',
            'sectionId': 's',
            'start': 10,
            'end': 4,
            'excerpt': 'x',
            'createdAt': '2026-01-01T00:00:00Z',
          },
        ],
      });
      expect(
        () => UserLibraryCodec.decode(broken),
        throwsA(isA<LibraryFormatException>()),
      );
    });
  });

  group('When stored data cannot be read', () {
    test('the reader still gets an app, and their bytes are kept', () async {
      final store = InMemoryStore(<String, String>{
        StoredUserDataRepository.libraryKey: '{"version": 99}',
      });
      final repository = StoredUserDataRepository(store);

      final library = await repository.load();

      // The app opens.
      expect(library.isEmpty, isTrue);
      // The original document is set aside rather than destroyed.
      expect(repository.salvagedDocument(), '{"version": 99}');
      // And the unreadable copy is out of the way, so the next save cannot
      // overwrite it.
      expect(store.read(StoredUserDataRepository.libraryKey), isNull);
    });

    test('a first run with nothing stored is not an error', () async {
      final repository = StoredUserDataRepository(InMemoryStore());
      expect((await repository.load()).isEmpty, isTrue);
      expect(repository.salvagedDocument(), isNull);
    });

    test('clearing removes the salvaged copy too', () async {
      final store = InMemoryStore(<String, String>{
        StoredUserDataRepository.libraryKey: 'broken',
      });
      final repository = StoredUserDataRepository(store);
      await repository.load();
      expect(repository.salvagedDocument(), isNotNull);

      await repository.clear();

      // Deleting your data must not leave a copy behind.
      expect(repository.salvagedDocument(), isNull);
      expect(store.keys(), isEmpty);
    });
  });

  group('Highlights when the content underneath them changes', () {
    const original =
        'The prisoners are chained facing a wall and see only shadows.';

    Highlight highlightOf(int start, int end) => Highlight(
      id: 'h',
      target: plato,
      sectionId: 'cave',
      start: start,
      end: end,
      excerpt: original.substring(start, end),
      createdAt: when,
    );

    test('an unchanged passage stays anchored', () {
      final highlight = highlightOf(4, 13);
      expect(highlight.isAnchoredIn(original), isTrue);
      expect(highlight.reanchoredIn(original), same(highlight));
    });

    test('a passage that moved is found again at its new offsets', () {
      final highlight = highlightOf(4, 13);
      const edited =
          'In the allegory, the prisoners are chained facing a wall.';

      expect(highlight.isAnchoredIn(edited), isFalse);
      final moved = highlight.reanchoredIn(edited);
      expect(moved, isNotNull);
      expect(edited.substring(moved!.start, moved.end), 'prisoners');
    });

    test('a passage that has gone is not guessed at', () {
      final highlight = highlightOf(4, 13);
      const rewritten = 'The captives see only shadows on the wall.';
      expect(highlight.reanchoredIn(rewritten), isNull);
    });

    test('an ambiguous passage is not guessed at either', () {
      // The text has moved (so the old offsets no longer match) and the excerpt
      // now occurs twice. Picking one would silently relocate the reader's mark
      // to a sentence they never marked.
      final highlight = highlightOf(4, 13);
      const doubled =
          'In it, the prisoners are chained. The prisoners see shadows.';

      expect(highlight.isAnchoredIn(doubled), isFalse);
      expect(highlight.reanchoredIn(doubled), isNull);
    });

    test('text that still matches at the old offsets stays put', () {
      // Even if the excerpt also appears elsewhere: the mark is where the
      // reader left it, and there is nothing to resolve.
      final highlight = highlightOf(4, 13);
      const doubled = 'The prisoners are chained. The prisoners see shadows.';
      expect(highlight.reanchoredIn(doubled), same(highlight));
    });

    test('a highlight past the end of shortened text is detected', () {
      final highlight = highlightOf(4, 13);
      expect(highlight.isAnchoredIn('Short.'), isFalse);
    });
  });

  group('Library operations', () {
    test('bookmarking is a toggle', () {
      var library = UserLibrary.empty;
      expect(library.isBookmarked(plato), isFalse);

      library = library.toggleBookmark(plato, at: when);
      expect(library.isBookmarked(plato), isTrue);

      library = library.toggleBookmark(plato, at: when);
      expect(library.isBookmarked(plato), isFalse);
    });

    test('everything the reader touched is listed, most recent first', () {
      final library = UserLibrary.empty
          .toggleBookmark(plato, at: when)
          .withNote(
            Note(
              id: 'n',
              target: forms,
              body: 'later',
              createdAt: when,
              updatedAt: when.add(const Duration(days: 1)),
            ),
          );

      // An annotated article the reader never bookmarked must still be findable.
      expect(library.touchedTargets, <EntityRef>[forms, plato]);
    });

    test('forgetting an article removes every trace of it', () {
      final library = populated().withoutTarget(plato);
      expect(library.isBookmarked(plato), isFalse);
      expect(library.notesFor(plato), isEmpty);
      expect(library.highlightsFor(plato), isEmpty);
      expect(library.positionFor(plato), isNull);
      // And leaves everything else alone.
      expect(library.notesFor(forms), hasLength(1));
    });

    test('highlights come back in reading order', () {
      final library = UserLibrary.empty
          .withHighlight(
            Highlight(
              id: 'b',
              target: plato,
              sectionId: 'cave',
              start: 50,
              end: 60,
              excerpt: 'second',
              createdAt: when,
            ),
          )
          .withHighlight(
            Highlight(
              id: 'a',
              target: plato,
              sectionId: 'cave',
              start: 10,
              end: 20,
              excerpt: 'first',
              createdAt: when,
            ),
          );

      expect(
        library.highlightsIn(plato, 'cave').map((h) => h.excerpt),
        <String>['first', 'second'],
      );
    });

    test('a barely-opened article is not worth restoring', () {
      expect(
        ReadingPosition(
          target: plato,
          scrollOffset: 12,
          updatedAt: when,
        ).isWorthRestoring,
        isFalse,
      );
      expect(
        ReadingPosition(
          target: plato,
          scrollOffset: 1200,
          updatedAt: when,
        ).isWorthRestoring,
        isTrue,
      );
    });
  });

  group('The controller', () {
    /// A container wired to an in-memory store.
    (ProviderContainer, InMemoryStore) build({UserLibrary? initial}) {
      final store = InMemoryStore();
      final container = ProviderContainer(
        overrides: [
          userDataRepositoryProvider.overrideWithValue(
            StoredUserDataRepository(store),
          ),
          initialLibraryProvider.overrideWithValue(
            initial ?? UserLibrary.empty,
          ),
        ],
      );
      addTearDown(container.dispose);
      return (container, store);
    }

    test('a bookmark is persisted, not just shown', () async {
      final (container, store) = build();
      final controller = container.read(libraryProvider.notifier);

      expect(await controller.toggleBookmark(plato), isTrue);

      final stored = UserLibraryCodec.decode(
        store.read(StoredUserDataRepository.libraryKey)!,
      );
      expect(stored.isBookmarked(plato), isTrue);
    });

    test('a note is given an identifier and stored', () async {
      final (container, store) = build();
      final controller = container.read(libraryProvider.notifier);

      final note = await controller.addNote(
        target: plato,
        body: '  worth returning to  ',
      );

      expect(note, isNotNull);
      expect(note!.body, 'worth returning to', reason: 'should be trimmed');
      expect(
        UserLibraryCodec.decode(
          store.read(StoredUserDataRepository.libraryKey)!,
        ).notes.single.id,
        note.id,
      );
    });

    test('an empty note is not created', () async {
      final (container, _) = build();
      final controller = container.read(libraryProvider.notifier);
      expect(await controller.addNote(target: plato, body: '   '), isNull);
      expect(container.read(libraryProvider).notes, isEmpty);
    });

    test('editing a note to nothing deletes it', () async {
      final (container, _) = build();
      final controller = container.read(libraryProvider.notifier);
      final note = await controller.addNote(target: plato, body: 'draft');

      await controller.editNote(note!.id, '');

      expect(container.read(libraryProvider).notes, isEmpty);
    });

    test(
      'two notes made in the same instant get different identifiers',
      () async {
        final (container, _) = build();
        final controller = container.read(libraryProvider.notifier);
        final first = await controller.addNote(target: plato, body: 'one');
        final second = await controller.addNote(target: plato, body: 'two');
        expect(first!.id, isNot(second!.id));
      },
    );

    test(
      'a failed write does not leave the interface claiming it saved',
      () async {
        final (container, store) = build();
        final controller = container.read(libraryProvider.notifier);
        store.failWrites = true;

        final saved = await controller.toggleBookmark(plato);

        expect(saved, isFalse);
        expect(
          container.read(libraryProvider).isBookmarked(plato),
          isFalse,
          reason:
              'the bookmark was not stored, so the button must not show it as '
              'saved — otherwise the reader loses it without ever being told',
        );
      },
    );

    test('clearing removes everything', () async {
      final (container, store) = build();
      final controller = container.read(libraryProvider.notifier);
      await controller.toggleBookmark(plato);
      await controller.addNote(target: plato, body: 'a note');

      expect(await controller.clearAll(), isTrue);

      expect(container.read(libraryProvider).isEmpty, isTrue);
      expect(store.keys(), isEmpty);
    });
  });

  group('Changing language does not disturb saved work', () {
    test('bookmarks and notes survive switching to Persian and back', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final store = InMemoryStore();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          userDataRepositoryProvider.overrideWithValue(
            StoredUserDataRepository(store),
          ),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
        ],
      );
      addTearDown(container.dispose);

      final library = container.read(libraryProvider.notifier);
      await library.toggleBookmark(plato);
      await library.addNote(target: plato, body: 'کاوش در نظریهٔ مُثُل');

      final settings = container.read(settingsProvider.notifier);
      await settings.setLanguage(AppLanguage.fa);
      await settings.setLanguage(AppLanguage.en);
      await settings.setLanguage(null);

      // The brief calls this out explicitly, and it is exactly the kind of thing
      // that breaks silently: language is a presentation choice and must never
      // touch what the reader has made.
      final after = container.read(libraryProvider);
      expect(after.isBookmarked(plato), isTrue);
      expect(after.notesFor(plato).single.body, 'کاوش در نظریهٔ مُثُل');

      final stored = UserLibraryCodec.decode(
        store.read(StoredUserDataRepository.libraryKey)!,
      );
      expect(stored.notesFor(plato).single.body, 'کاوش در نظریهٔ مُثُل');
    });
  });
}
