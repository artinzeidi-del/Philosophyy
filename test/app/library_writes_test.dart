import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/repositories/user_data_repository.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// Storage has to end up holding the last thing the reader did.
///
/// ## The defect this is written against
///
/// Every library operation used to update state and then `await` a save, with
/// no relationship between one save and the next. Two taps close together —
/// bookmarking two articles, or typing a note while a highlight is still being
/// written — start two saves of two different libraries, and nothing in the
/// repository contract says the first finishes first. A slow write of the older
/// library landing after a fast write of the newer one leaves storage a version
/// behind the screen: the reader sees both bookmarks, closes the app, and comes
/// back to one.
///
/// It is not a hypothetical of the fake below. `SharedPreferences` goes through
/// a platform channel, and channel replies are not ordered against each other;
/// a large library that has to be re-encoded takes longer than a small one.
///
/// The fix chains each write onto the tail of the previous one, so the order on
/// disk is the order the reader made. These tests hold that: the first checks
/// the result the reader cares about, the rest hold the ordering and the
/// failure handling that could quietly regress.
void main() {
  test(
    'the reader keeps both actions when the older write is slower',
    () async {
      final store = _OutOfOrderStore(<int>[60, 0]);
      final container = _containerWith(store);
      addTearDown(container.dispose);

      final library = container.read(libraryProvider.notifier);
      final first = library.toggleBookmark(
        const EntityRef(EntityKind.philosopher, 'thales'),
      );
      final second = library.toggleBookmark(
        const EntityRef(EntityKind.philosopher, 'plato'),
      );
      await Future.wait(<Future<bool>>[first, second]);

      expect(store.saved.last.bookmarks, hasLength(2));
    },
  );

  test('writes reach storage in the order the reader made them', () async {
    final store = _OutOfOrderStore(<int>[60, 0]);
    final container = _containerWith(store);
    addTearDown(container.dispose);

    final library = container.read(libraryProvider.notifier);
    final first = library.toggleBookmark(
      const EntityRef(EntityKind.philosopher, 'thales'),
    );
    final second = library.toggleBookmark(
      const EntityRef(EntityKind.philosopher, 'plato'),
    );
    await Future.wait(<Future<bool>>[first, second]);

    expect(
      store.saved.map((library) => library.bookmarks.length),
      <int>[1, 2],
      reason:
          'a one-bookmark library written after a two-bookmark one loses '
          'the second bookmark',
    );
  });

  test('a slow first write does not swallow the second result', () async {
    final store = _OutOfOrderStore(<int>[60, 0]);
    final container = _containerWith(store);
    addTearDown(container.dispose);

    final library = container.read(libraryProvider.notifier);
    final results = await Future.wait(<Future<bool>>[
      library.toggleBookmark(const EntityRef(EntityKind.philosopher, 'thales')),
      library.toggleBookmark(const EntityRef(EntityKind.philosopher, 'plato')),
    ]);

    expect(results, <bool>[true, true]);
  });

  test('a failed write does not undo a later one that succeeded', () async {
    final store = _FirstWriteFails();
    final container = _containerWith(store);
    addTearDown(container.dispose);

    final library = container.read(libraryProvider.notifier);
    final failed = library.toggleBookmark(
      const EntityRef(EntityKind.philosopher, 'thales'),
    );
    final saved = library.toggleBookmark(
      const EntityRef(EntityKind.philosopher, 'plato'),
    );

    expect(await failed, isFalse);
    expect(await saved, isTrue);
    expect(
      container.read(libraryProvider).bookmarks,
      hasLength(2),
      reason:
          'rolling back to the library before the failed write would take '
          'away the bookmark that did save',
    );
  });

  test('a lone failed write is rolled back off the screen', () async {
    final store = _FirstWriteFails();
    final container = _containerWith(store);
    addTearDown(container.dispose);

    final library = container.read(libraryProvider.notifier);
    expect(
      await library.toggleBookmark(
        const EntityRef(EntityKind.philosopher, 'thales'),
      ),
      isFalse,
    );
    expect(container.read(libraryProvider).bookmarks, isEmpty);
  });
}

ProviderContainer _containerWith(UserDataRepository store) => ProviderContainer(
  overrides: [
    userDataRepositoryProvider.overrideWithValue(store),
    initialLibraryProvider.overrideWithValue(UserLibrary.empty),
  ],
);

/// A repository whose writes finish in an order of the test's choosing.
class _OutOfOrderStore implements UserDataRepository {
  _OutOfOrderStore(this.delaysMs);

  /// How long the nth save takes, in milliseconds.
  final List<int> delaysMs;

  /// Every library handed to [save], in the order the writes completed.
  final List<UserLibrary> saved = <UserLibrary>[];

  int _calls = 0;

  @override
  Future<void> save(UserLibrary library) async {
    final delay = _calls < delaysMs.length ? delaysMs[_calls] : 0;
    _calls++;
    await Future<void>.delayed(Duration(milliseconds: delay));
    saved.add(library);
  }

  @override
  Future<UserLibrary> load() async => UserLibrary.empty;

  @override
  String? salvagedDocument() => null;

  @override
  Future<void> clear() async {}
}

/// A repository that rejects the first write and accepts the rest.
class _FirstWriteFails implements UserDataRepository {
  int _calls = 0;

  @override
  Future<void> save(UserLibrary library) async {
    _calls++;
    if (_calls == 1) throw StateError('the disk is full');
  }

  @override
  Future<UserLibrary> load() async => UserLibrary.empty;

  @override
  String? salvagedDocument() => null;

  @override
  Future<void> clear() async {}
}
