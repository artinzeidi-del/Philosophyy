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
      await _store.write(salvageKey, raw);
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
  String? salvagedDocument() => _store.read(salvageKey);

  @override
  Future<void> clear() async {
    await _store.delete(libraryKey);
    await _store.delete(salvageKey);
  }
}
