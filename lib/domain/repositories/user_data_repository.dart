import 'package:philosophyy/domain/entities/user_data.dart';

/// Stores what the reader has made.
///
/// The whole library is loaded and saved at once. That is appropriate at this
/// size — a reader's bookmarks, notes and highlights are kilobytes — and it
/// makes every operation above this layer a pure function from one library value
/// to the next, with no partial-write states to reason about.
abstract interface class UserDataRepository {
  /// Loads the reader's library.
  ///
  /// Never throws. A library that cannot be read is set aside for recovery and
  /// an empty one is returned, because failing to open the app is a worse
  /// outcome for the reader than temporarily not seeing their notes.
  Future<UserLibrary> load();

  /// Persists [library].
  ///
  /// Throws if the write fails, so callers can tell the reader that something
  /// they typed was not saved.
  Future<void> save(UserLibrary library);

  /// The unreadable document set aside by a failed [load], if there is one.
  ///
  /// Exposed so that a future recovery path — or a support conversation — can
  /// reach the reader's original bytes.
  String? salvagedDocument();

  /// Discards everything, including any salvaged document.
  ///
  /// This is the reader exercising their right to delete their own data, so it
  /// must leave nothing behind.
  Future<void> clear();
}
