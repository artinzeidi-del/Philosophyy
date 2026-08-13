import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/settings/app_settings.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/repositories/knowledge_repository.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
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
