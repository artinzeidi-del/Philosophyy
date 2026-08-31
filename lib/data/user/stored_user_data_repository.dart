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
      // Set the original aside before returning an empty library, so that the
      // next save cannot overwrite bytes we failed to understand.
      //
      // Beside any earlier salvage, not on top of it. Writing to the one key
      // meant a second unreadable document destroyed the first — and the first
      // is the one likely to hold the reader's own writing, since by the time
      // a second appears the library has already been reset to empty once.
      // That is the one thing this whole path exists to prevent, and it did
      // the opposite in silence.
      final slot = _freeSalvageSlot();
      if (slot != null) {
        await _store.write(salvageKeyAt(slot), raw);
      } else {
        debugPrint(
          'Already holding $maxSalvaged salvaged libraries; keeping those and '
          'dropping this one.',
        );
      }
      await _store.delete(libraryKey);
      debugPrint(
        'Saved library could not be read and was set aside under '
        '"$salvageKey": $error',
      );
      assert(() {
        debugPrintStack(stackTrace: stack);
        return true;
      }());
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

  /// The first salvage slot with nothing in it, or null when all are taken.
  int? _freeSalvageSlot() {
    for (var index = 0; index < maxSalvaged; index++) {
      if (_store.read(salvageKeyAt(index)) == null) return index;
    }
    return null;
  }
}
