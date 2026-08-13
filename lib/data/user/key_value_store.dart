import 'package:shared_preferences/shared_preferences.dart';

/// Somewhere to put a string and get it back.
///
/// The reader's library is stored through this rather than against
/// `SharedPreferences` directly, so the repository can be tested without a
/// platform channel, and so the backing store can be replaced without touching
/// anything above it.
abstract interface class KeyValueStore {
  /// The value at [key], or `null` if nothing is stored there.
  String? read(String key);

  /// Stores [value] at [key].
  Future<void> write(String key, String value);

  /// Removes whatever is at [key].
  Future<void> delete(String key);

  /// Every key currently in use, for export and diagnostics.
  Set<String> keys();
}

/// The production store, backed by the platform's preferences.
///
/// This is the right size of tool for the data. A reader's bookmarks, notes and
/// highlights are kilobytes; preferences are available on every platform the app
/// targets, including web, and need no native setup. See ADR 15 for the point at
/// which this stops being true.
class PreferencesStore implements KeyValueStore {
  const PreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);

  @override
  Set<String> keys() => _preferences.getKeys();
}

/// An in-memory store, for tests.
class InMemoryStore implements KeyValueStore {
  InMemoryStore([Map<String, String>? initial])
    : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  /// Set to make every write fail, so that failure handling can be exercised.
  bool failWrites = false;

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('storage unavailable');
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Set<String> keys() => _values.keys.toSet();
}
