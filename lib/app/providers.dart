import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/settings/app_settings.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/stored_user_data_repository.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/repositories/knowledge_repository.dart';
import 'package:philosophyy/domain/repositories/user_data_repository.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supplies persisted preferences.
///
/// Overridden in `main` with an instance loaded before the first frame, so that
/// nothing downstream has to be asynchronous and the app never renders in one
/// theme and then jumps to another.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider must be overridden in ProviderScope. '
    'See bootstrap() in lib/main.dart.',
  ),
);

/// The content repository.
final knowledgeRepositoryProvider = Provider<KnowledgeRepository>(
  (ref) => const AssetKnowledgeRepository(),
);

/// The corpus, loaded once.
///
/// Everything downstream reads the loaded corpus synchronously; only the
/// root of the app deals with its loading and error states.
final corpusProvider = FutureProvider<KnowledgeBase>(
  (ref) => ref.watch(knowledgeRepositoryProvider).load(),
);

/// The search index, built once the corpus is available.
///
/// Building the index is pure work over immutable data, so it is derived rather
/// than stored, and rebuilt only if the corpus itself is ever replaced.
final searchIndexProvider = Provider<SearchIndex>((ref) {
  final corpus = ref.watch(corpusProvider).value;
  if (corpus == null) return SearchIndex.build(KnowledgeBase.empty);
  return SearchIndex.build(corpus);
});

/// The reader's preferences, persisted on every change.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Reads and writes [AppSettings].
///
/// Writes are fire-and-forget against local storage: a preference that fails to
/// persist is worth a log line, not an error dialog that interrupts a reader
/// for something they will not notice and cannot fix.
class SettingsController extends Notifier<AppSettings> {
  /// Storage key for the language override.
  static const String languageKey = 'settings.language';

  /// Storage key for the theme mode.
  static const String themeKey = 'settings.themeMode';

  /// Storage key for the reading level.
  static const String levelKey = 'settings.readingLevel';

  @override
  AppSettings build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      language: _readLanguage(preferences),
      themeMode: _readThemeMode(preferences),
      readingLevel:
          LearningLevel.fromId(preferences.getString(levelKey) ?? '') ??
          LearningLevel.beginner,
    );
  }

  static AppLanguage? _readLanguage(SharedPreferences preferences) {
    final stored = preferences.getString(languageKey);
    if (stored == null) return null;
    for (final language in AppLanguage.values) {
      if (language.code == stored) return language;
    }
    return null;
  }

  static ThemeMode _readThemeMode(SharedPreferences preferences) =>
      switch (preferences.getString(themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Sets an explicit language, or clears the override when [language] is null.
  ///
  /// Changing language must never disturb anything the reader has built up —
  /// bookmarks, notes, progress — so it touches only this one key.
  Future<void> setLanguage(AppLanguage? language) async {
    state = language == null
        ? state.clearLanguage()
        : state.copyWith(language: language);
    final preferences = ref.read(sharedPreferencesProvider);
    if (language == null) {
      await preferences.remove(languageKey);
    } else {
      await preferences.setString(languageKey, language.code);
    }
  }

  /// Sets the theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(
      themeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  /// Sets the reader's declared level, which changes the depth entries open at.
  Future<void> setReadingLevel(LearningLevel level) async {
    state = state.copyWith(readingLevel: level);
    await ref.read(sharedPreferencesProvider).setString(levelKey, level.id);
  }
}

/// The language the interface is currently rendering in.
///
/// Resolved from the reader's choice and the platform locale together, so every
/// widget can ask one question instead of repeating that logic.
final activeLanguageProvider = Provider<AppLanguage>((ref) {
  final settings = ref.watch(settingsProvider);
  final chosen = settings.language;
  if (chosen != null) return chosen;
  final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
  return AppLanguage.fromCode(platformLocale.languageCode);
});

/// The live search query.
final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

/// Holds the text currently in the search field.
class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  /// Replaces the query.
  void set(String query) => state = query;

  /// Empties the query.
  void clear() => state = '';
}

/// Results for the live query, recomputed as the reader types.
final searchResultsProvider = Provider<List<SearchHit>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const <SearchHit>[];
  return ref.watch(searchIndexProvider).search(query);
});

/// The repository holding what the reader has made.
final userDataRepositoryProvider = Provider<UserDataRepository>(
  (ref) => StoredUserDataRepository(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  ),
);

/// The library as it stood when the app started.
///
/// Overridden in `main` with a value loaded before the first frame, for the same
/// reason as the preferences: a reader who bookmarked an article should not
/// watch the bookmark appear a frame after the screen does.
final initialLibraryProvider = Provider<UserLibrary>(
  (ref) => throw StateError(
    'initialLibraryProvider must be overridden in ProviderScope. '
    'See main() in lib/main.dart.',
  ),
);

/// What the reader has saved, and the operations that change it.
final libraryProvider = NotifierProvider<LibraryController, UserLibrary>(
  LibraryController.new,
);

/// Applies changes to the reader's library and persists them.
///
/// Every method updates state first and writes afterwards, returning whether the
/// write succeeded. The interface is optimistic because the alternative — a
/// spinner on a bookmark button — is worse for something that succeeds
/// essentially always; but the result is returned rather than swallowed, so a
/// screen can tell the reader when something they typed did not save.
class LibraryController extends Notifier<UserLibrary> {
  @override
  UserLibrary build() => ref.watch(initialLibraryProvider);

  UserDataRepository get _repository => ref.read(userDataRepositoryProvider);

  Future<bool> _commit(UserLibrary next) async {
    final previous = state;
    state = next;
    try {
      await _repository.save(next);
      return true;
    } on Object catch (error) {
      // Put the reader's view back to what is actually stored, so the interface
      // never shows a note as saved when it is not.
      state = previous;
      debugPrint('Could not save the library: $error');
      return false;
    }
  }

  /// Saves or unsaves an article.
  Future<bool> toggleBookmark(EntityRef target, {DateTime? at}) =>
      _commit(state.toggleBookmark(target, at: at ?? DateTime.now()));

  /// Adds a note, returning the note that was stored.
  Future<Note?> addNote({
    required EntityRef target,
    required String body,
    String? sectionId,
    DateTime? at,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    final now = at ?? DateTime.now();
    final note = Note(
      id: _identifier('note'),
      target: target,
      sectionId: sectionId,
      body: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    return await _commit(state.withNote(note)) ? note : null;
  }

  /// Replaces a note's text.
  Future<bool> editNote(String noteId, String body, {DateTime? at}) async {
    final trimmed = body.trim();
    final existing = state.notes.where((note) => note.id == noteId).firstOrNull;
    if (existing == null) return false;
    if (trimmed.isEmpty) return deleteNote(noteId);
    return _commit(
      state.withNote(existing.withBody(trimmed, at: at ?? DateTime.now())),
    );
  }

  /// Removes a note.
  Future<bool> deleteNote(String noteId) => _commit(state.withoutNote(noteId));

  /// Marks a passage.
  Future<Highlight?> addHighlight({
    required EntityRef target,
    required String sectionId,
    required int start,
    required int end,
    required String excerpt,
    DateTime? at,
  }) async {
    if (start < 0 || end <= start || excerpt.isEmpty) return null;
    final highlight = Highlight(
      id: _identifier('highlight'),
      target: target,
      sectionId: sectionId,
      start: start,
      end: end,
      excerpt: excerpt,
      createdAt: at ?? DateTime.now(),
    );
    return await _commit(state.withHighlight(highlight)) ? highlight : null;
  }

  /// Removes a marked passage.
  Future<bool> removeHighlight(String highlightId) =>
      _commit(state.withoutHighlight(highlightId));

  /// Records how far into an article the reader had got.
  ///
  /// Positions are written often, so a position that fails to save is not worth
  /// reverting the reader's view over — the next scroll will try again.
  Future<bool> recordPosition({
    required EntityRef target,
    required double scrollOffset,
    String? sectionId,
    DateTime? at,
  }) async {
    final next = state.withPosition(
      ReadingPosition(
        target: target,
        sectionId: sectionId,
        scrollOffset: scrollOffset,
        updatedAt: at ?? DateTime.now(),
      ),
    );
    state = next;
    try {
      await _repository.save(next);
      return true;
    } on Object {
      return false;
    }
  }

  /// Removes everything belonging to one article.
  Future<bool> forget(EntityRef target) => _commit(state.withoutTarget(target));

  /// Deletes everything the reader has made.
  Future<bool> clearAll() async {
    state = UserLibrary.empty;
    try {
      await _repository.clear();
      return true;
    } on Object catch (error) {
      debugPrint('Could not clear the library: $error');
      return false;
    }
  }

  /// A short, sortable, collision-resistant identifier.
  ///
  /// Time-ordered so that notes created in sequence sort in that order even
  /// before their timestamps are compared, with a counter to separate two made
  /// inside the same millisecond.
  String _identifier(String prefix) {
    _sequence = (_sequence + 1) % 100000;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  int _sequence = 0;
}

/// Whether a given article is bookmarked.
///
/// A dedicated provider so that a bookmark button rebuilds when its own article
/// is saved, rather than every time anything anywhere in the library changes.
final isBookmarkedProvider = Provider.family<bool, EntityRef>(
  (ref, target) => ref.watch(
    libraryProvider.select((library) => library.isBookmarked(target)),
  ),
);

/// The notes on a given article.
final notesForProvider = Provider.family<List<Note>, EntityRef>(
  (ref, target) =>
      ref.watch(libraryProvider.select((library) => library.notesFor(target))),
);
