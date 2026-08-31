import 'package:flutter/foundation.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/user_library_codec.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/repositories/user_data_repository.dart';

/// Keeps the reader's library in a [KeyValueStore].
class StoredUserDataRepository implements UserDataRepository {
  const StoredUserDataRepository(this._store);

  /// Where the library lives.
  static const String libraryKey = 'library.v1';

  /// Where an unreadable library is set aside.
  ///
  /// A document that fails to parse is moved here rather than overwritten. The
  /// reader loses sight of their notes until a recovery path exists; they do not
  /// lose the notes.
  static const String salvageKey = 'library.salvaged';

  /// The most salvaged documents kept before the newest is dropped instead.
  ///
  /// A bound is needed — nothing else prunes these — and the *newest* is what
  /// gets dropped when it is reached, not the oldest. The first document to
  /// fail is the one most likely to hold what the reader actually wrote; the
  /// ones after it are increasingly likely to be the wreckage of a bug that
  /// has already eaten the notes.
  static const int maxSalvaged = 5;

  /// The key the nth salvaged document lives under.
  ///
  /// The first keeps the bare name so that a document set aside by an older
  /// build is still found.
  static String salvageKeyAt(int index) =>
      index == 0 ? salvageKey : '$salvageKey.${index + 1}';

  final KeyValueStore _store;

  @override
  Future<UserLibrary> load() async {
    final raw = _store.read(libraryKey);
    if (raw == null || raw.isEmpty) return UserLibrary.empty;

    try {
      return UserLibraryCodec.decode(raw);
    } on LibraryFormatException catch (error, stack) {
      // The original is set aside before an empty library is returned, so that
      // the next save cannot overwrite bytes we failed to understand.
      debugPrint('Saved library could not be read: $error');
      assert(() {
        debugPrintStack(stackTrace: stack);
        return true;
      }());
      await _setAside(raw);
      return UserLibrary.empty;
    }
  }

  @override
  Future<void> save(UserLibrary library) =>
      _store.write(libraryKey, UserLibraryCodec.encode(library));

  @override
  String? salvagedDocument() {
    for (var index = 0; index < maxSalvaged; index++) {
      final found = _store.read(salvageKeyAt(index));
      if (found != null) return found;
    }
    return null;
  }

  /// Every document set aside, oldest first.
  List<String> salvagedDocuments() => <String>[
    for (var index = 0; index < maxSalvaged; index++)
      ?_store.read(salvageKeyAt(index)),
  ];

  @override
  Future<void> clear() async {
    await _store.delete(libraryKey);
    // Every slot, not just the first. Erasing your data has to erase all of it.
    for (var index = 0; index < maxSalvaged; index++) {
      await _store.delete(salvageKeyAt(index));
    }
  }

  /// Moves an unreadable document out of the way of the next save.
  ///
  /// Every step here is allowed to fail, and none of them may stop the app from
  /// opening. This runs on the way to the first frame: a device that refuses the
  /// write used to throw out of [load], out of `main`, and the reader got a
  /// blank window with nothing on it to explain itself. Starting empty is a bad
  /// launch; not starting is not a launch.
  ///
  /// The order matters. The document is only removed once a copy is safely
  /// beside it, so a failure leaves the original bytes where they are — still
  /// unreadable, still the reader's, and still there to be recovered — rather
  /// than deleting the one copy in the name of protecting it.
  Future<void> _setAside(String raw) async {
    try {
      if (_isAlreadySalvaged(raw)) {
        // A previous launch copied this and then failed to remove the original.
        // Copying it again would spend another of the five slots on a duplicate.
        await _store.delete(libraryKey);
        return;
      }
      // Beside any earlier salvage, not on top of it. Writing to the one key
      // meant a second unreadable document destroyed the first — and the first
      // is the one likely to hold the reader's own writing, since by the time a
      // second appears the library has already been reset to empty once. That
      // is the one thing this whole path exists to prevent.
      final slot = _freeSalvageSlot();
      if (slot == null) {
        debugPrint(
          'Already holding $maxSalvaged salvaged libraries; keeping those and '
          'dropping this one.',
        );
        return;
      }
      await _store.write(salvageKeyAt(slot), raw);
      await _store.delete(libraryKey);
      debugPrint('It was set aside under "${salvageKeyAt(slot)}".');
    } on Object catch (error) {
      debugPrint(
        'It could not be set aside and has been left where it is: $error',
      );
    }
  }

  /// Whether [raw] is already sitting in one of the salvage slots.
  bool _isAlreadySalvaged(String raw) {
    for (var index = 0; index < maxSalvaged; index++) {
      if (_store.read(salvageKeyAt(index)) == raw) return true;
    }
    return false;
  }

  /// The first salvage slot with nothing in it, or null when all are taken.
  int? _freeSalvageSlot() {
    for (var index = 0; index < maxSalvaged; index++) {
      if (_store.read(salvageKeyAt(index)) == null) return index;
    }
    return null;
  }
}
