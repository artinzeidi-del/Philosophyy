import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/settings/app_settings.dart';
import 'package:philosophyy/core/quiz/quiz_builder.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/core/search/text_normalizer.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/stored_user_data_repository.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/quiz.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/repositories/knowledge_repository.dart';
import 'package:philosophyy/domain/repositories/user_data_repository.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/ranks.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
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
///
/// ## Why it is warmed rather than left to be asked for
///
/// A `Provider` is lazy, and [searchResultsProvider] returns early for an empty
/// query without reading this one. So nothing built the index until the reader
/// pressed the first key in the search box — and the build then ran on the UI
/// isolate and held it for the better part of a second. Typing one letter and
/// watching the app stop is precisely the "sluggish" the reader reported.
///
/// The work is the same work; the only question is when it is done.
/// [warmSearchIndex] moves it to the moment the search screen opens, which is
/// the last quiet moment before a reader can possibly need it.
final searchIndexProvider = Provider<SearchIndex>((ref) {
  final corpus = ref.watch(corpusProvider).value;
  if (corpus == null) return SearchIndex.build(KnowledgeBase.empty);
  return SearchIndex.build(corpus);
});

/// Builds the search index ahead of the reader needing it.
///
/// Reading the provider is what builds it, and Riverpod caches the result, so
/// this is a request rather than a value.
///
/// Called when the search screen appears rather than when the app starts. The
/// screen is on the reader's path to typing and nothing else is: warming at
/// launch would make every screen wait for a structure most sessions never
/// touch, and would put the same cost into every widget test that opens the
/// app. Warming here puts it in the gap between arriving at the search box and
/// pressing a key, which is exactly where there is time to spare.
///
/// Does nothing if the corpus has not arrived yet — [searchIndexProvider]
/// watches it and will rebuild when it does, so building now would only
/// produce an index of nothing.
void warmSearchIndex(WidgetRef ref) {
  if (ref.read(corpusProvider).value == null) return;
  ref.read(searchIndexProvider);
}

/// The round of questions in progress, or `null` when none has been started.
///
/// ## Why this is not widget state
///
/// The obvious home for a round is the quiz screen's own `State`, and it was
/// there first. But the round *is* what the app is doing while the reader is
/// answering — which question they are on and what they have chosen is the
/// whole of the screen's meaning — and nothing outside the widget could see it.
/// A test could press buttons but not tell which one was right, so the only
/// checks available were structural ones that would pass on a quiz that marked
/// every answer wrong.
final quizSessionProvider =
    NotifierProvider<QuizSessionController, QuizSession?>(
      QuizSessionController.new,
    );

/// One round: the questions, and how far the reader has got.
class QuizSession {
  const QuizSession({
    required this.questions,
    this.answers = const <int>[],
    this.pending,
  });

  /// The questions, in the order they are asked.
  final List<QuizQuestion> questions;

  /// What the reader chose, one per question they have finished with.
  final List<int> answers;

  /// The choice on the current question, before they move on.
  ///
  /// Separate from [answers] because a chosen answer is shown as right or wrong
  /// before it is committed — the reader sees the verdict, then presses on.
  final int? pending;

  /// The question the reader is looking at, or `null` when the round is over.
  QuizQuestion? get current =>
      answers.length < questions.length ? questions[answers.length] : null;

  /// Whether every question has been answered.
  bool get isFinished =>
      questions.isNotEmpty && answers.length >= questions.length;

  /// Where the reader is, counting from one.
  int get position => answers.length + 1;

  /// The round's outcome so far.
  QuizResult get result => QuizResult(answers: answers, questions: questions);

  QuizSession copyWith({
    List<int>? answers,
    int? pending,
    bool clearPending = false,
  }) => QuizSession(
    questions: questions,
    answers: answers ?? this.answers,
    pending: clearPending ? null : (pending ?? this.pending),
  );
}

/// Starts, advances and ends a round.
class QuizSessionController extends Notifier<QuizSession?> {
  @override
  QuizSession? build() => null;

  /// Builds a fresh round from the entries the reader has marked read.
  ///
  /// [l10n] is passed in rather than read here because the question text is
  /// written in the reader's language at build time, and localisations belong
  /// to the widget tree.
  void start(AppL10n l10n, {int? seed}) {
    final corpus = ref.read(corpusProvider).value;
    if (corpus == null) return;
    state = QuizSession(
      questions: QuizBuilder.build(
        corpus: corpus,
        subjects: ref.read(readTargetsProvider),
        l10n: l10n,
        language: ref.read(activeLanguageProvider),
        seed: seed ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Records the reader's choice on the current question.
  ///
  /// Ignored once a choice has been made. A quiz that lets an answer be changed
  /// after showing whether it was right is not measuring anything.
  void choose(int index) {
    final session = state;
    if (session == null || session.pending != null) return;
    state = session.copyWith(pending: index);
  }

  /// Commits the choice and moves on.
  ///
  /// A fact answered correctly is banked here rather than at the end of the
  /// round, so a reader who leaves halfway keeps what they got right. Leaving
  /// is not failing.
  void advance() {
    final session = state;
    final chosen = session?.pending;
    if (session == null || chosen == null) return;

    final question = session.current;
    if (question != null && question.isCorrect(chosen)) {
      unawaited(ref.read(libraryProvider.notifier).master(question.fact));
    }

    state = session.copyWith(
      answers: <int>[...session.answers, chosen],
      clearPending: true,
    );
  }

  /// Abandons the round, returning the screen to its starting state.
  void reset() => state = null;
}

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

/// Searches the reader has run before, most recent first.
final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
      RecentSearchesController.new,
    );

/// Remembers what the reader looked for, so the search screen has something to
/// offer before they type.
///
/// ## What counts as a search
///
/// Only a query the reader acted on — one where they opened a result. A live
/// search box sees every prefix of every word, and a history built from
/// keystrokes fills with `a`, `ar`, `ari`, `aris` and tells the reader nothing
/// they did not already know a moment later.
class RecentSearchesController extends Notifier<List<String>> {
  /// Storage key for the history.
  static const String storageKey = 'search.recent';

  /// How many are kept.
  ///
  /// Short on purpose: this is a shortcut back to something the reader was just
  /// doing, not a record of their reading. A long list is harder to scan than
  /// retyping the word.
  static const int limit = 6;

  /// Separates entries in storage.
  ///
  /// A newline, because a query can contain anything else a reader can type —
  /// including the commas and semicolons an obvious separator would use — but
  /// cannot contain a line break: the field is single-line.
  static const String _separator = '\n';

  @override
  List<String> build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(storageKey);
    if (stored == null || stored.isEmpty) return const <String>[];
    return stored
        .split(_separator)
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  /// Records [query], moving it to the front if it is already known.
  ///
  /// Comparison is case-insensitive and ignores surrounding space, so
  /// searching "Plato" after "plato " does not produce two entries that look
  /// identical to a reader.
  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final folded = trimmed.toLowerCase();
    final next = <String>[
      trimmed,
      for (final existing in state)
        if (existing.toLowerCase() != folded) existing,
    ];
    state = next.length <= limit ? next : next.sublist(0, limit);
    await _persist();
  }

  /// Forgets everything.
  Future<void> clear() async {
    state = const <String>[];
    await _persist();
  }

  /// Writes the history, and gives up quietly if it cannot.
  ///
  /// Every other write in the app is guarded — a library that fails to save
  /// tells the reader so — but this one is neither worth a message nor worth
  /// an uncaught error. Both callers fire and forget, so a throw here would
  /// surface as an unhandled async error while the reader was doing something
  /// else entirely, and what would be lost is a shortcut back to a word they
  /// can retype.
  ///
  /// Untested: `SharedPreferences` offers no way to make a write fail from a
  /// test, so this is written from the contract rather than against a
  /// reproduction.
  Future<void> _persist() async {
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(storageKey, state.join(_separator));
    } on Object catch (error) {
      debugPrint('Could not save the search history: $error');
    }
  }
}

/// Entries to offer a reader who has not typed anything yet.
///
/// ## Why these entries
///
/// The obvious thing is a hand-written list of famous names, and it would be a
/// small lie: it would say "start here" on grounds that are really the editor's
/// taste, and it would fossilise as the corpus grew. These are the entities the
/// corpus itself connects to most — the ones the most articles point at — which
/// is a fact about the material rather than an opinion about it, and which
/// changes on its own as entries are added.
final searchStartingPointsProvider = Provider<List<KnowledgeEntity>>((ref) {
  final corpus = ref.watch(corpusProvider).value;
  if (corpus == null) return const <KnowledgeEntity>[];

  final entities = corpus.allEntities.toList();
  entities.sort((a, b) {
    final byConnections = corpus
        .relationsFor(b.ref)
        .length
        .compareTo(corpus.relationsFor(a.ref).length);
    // Ties break by name so the list is the same on every launch. A "suggested"
    // row that reshuffles between visits reads as randomness, and a reader who
    // saw something a moment ago should be able to find it again.
    return byConnections != 0
        ? byConnections
        : a.name.en.toLowerCase().compareTo(b.name.en.toLowerCase());
  });

  return entities.take(8).toList(growable: false);
});

/// Completions for the word the reader is in the middle of typing.
///
/// [SearchIndex.suggestions] has existed since the index was written, is
/// covered by tests, and was called by nothing — so a reader who typed
/// «اپیک» saw whatever that prefix scored and no hint that «اپیکوری» was a
/// word the corpus knows.
///
/// Only the last word is completed. The earlier words of a query are ones the
/// reader has finished with, and offering to rewrite them turns a search box
/// into an argument.
final searchCompletionsProvider = Provider<List<String>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final lastWord = query.split(RegExp(r'\s+')).last;
  if (lastWord.isEmpty) return const <String>[];

  final normalized = TextNormalizer.normalize(lastWord);
  return ref
      .watch(searchIndexProvider)
      .suggestions(lastWord)
      // A completion identical to what is already typed is not a completion.
      .where((suggestion) => suggestion != normalized)
      .toList(growable: false);
});

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

  /// The tail of the write queue.
  ///
  /// Two taps in quick succession start two writes, and nothing in a repository
  /// promises the first finishes first — a slow write of the older library can
  /// land after a fast write of the newer one, leaving storage a version behind
  /// the screen until the next change happens to cover it. Chaining every write
  /// onto the previous one makes the order on disk the order the reader made.
  Future<void> _writes = Future<void>.value();

  /// Runs [write] after every write already queued, and puts it on the queue.
  ///
  /// Every path that touches storage goes through here — saves, position
  /// updates and the erase alike. A path that skipped it would be free to land
  /// between two queued writes, which is how a scroll position could overwrite a
  /// bookmark and how an erase could be undone by a save still in flight.
  Future<T> _enqueue<T>(Future<T> Function() write) {
    final done = _writes.then((_) => write());
    _writes = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }

  Future<bool> _commit(UserLibrary next) {
    final previous = state;
    state = next;

    return _enqueue(() async {
      try {
        await _repository.save(next);
        return true;
      } on Object catch (error) {
        // Put the reader's view back to what is actually stored, so the
        // interface never shows a note as saved when it is not. Only undo if
        // this is still the library on screen: a later change that did save
        // must not be rolled back by an earlier one that did not.
        if (ref.mounted && identical(state, next)) state = previous;
        debugPrint('Could not save the library: $error');
        return false;
      }
    });
  }

  /// Saves or unsaves an article.
  Future<bool> toggleBookmark(EntityRef target, {DateTime? at}) =>
      _commit(state.toggleBookmark(target, at: at ?? DateTime.now()));

  /// Marks an article read, or takes the mark off again.
  Future<bool> toggleRead(EntityRef target, {DateTime? at}) =>
      _commit(state.toggleRead(target, at: at ?? DateTime.now()));

  /// Records that the reader has answered a question about [fact] correctly.
  ///
  /// Returns without writing when the fact is already known, so re-answering
  /// something costs nothing and changes nothing.
  Future<bool> master(String fact) {
    final next = state.withMastered(<String>[fact]);
    if (identical(next, state)) return Future<bool>.value(true);
    return _commit(next);
  }

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
    return _enqueue(() async {
      try {
        await _repository.save(next);
        return true;
      } on Object {
        return false;
      }
    });
  }

  /// Removes everything belonging to one article.
  Future<bool> forget(EntityRef target) => _commit(state.withoutTarget(target));

  /// Deletes everything the reader has made.
  ///
  /// Queued behind the writes already in flight, so that a save started a moment
  /// earlier cannot land afterwards and put back what was just erased.
  Future<bool> clearAll() {
    state = UserLibrary.empty;
    return _enqueue(() async {
      try {
        await _repository.clear();
        return true;
      } on Object catch (error) {
        debugPrint('Could not clear the library: $error');
        return false;
      }
    });
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

/// Whether the reader has marked a given article as read.
final hasReadProvider = Provider.family<bool, EntityRef>(
  (ref, target) =>
      ref.watch(libraryProvider.select((library) => library.hasRead(target))),
);

/// Everything the reader has said they finished, as a set.
///
/// A set rather than the list on the library, because the quiz asks "is this
/// one of them" once per entry it considers.
final readTargetsProvider = Provider<Set<EntityRef>>(
  (ref) => ref.watch(
    libraryProvider.select(
      (library) => <EntityRef>{
        for (final mark in library.readMarks) mark.target,
      },
    ),
  ),
);

/// Every fact the corpus can build a question about.
///
/// The denominator of the reader's rank, and a property of the corpus rather
/// than of how much they have read — see [Ranks] for why it has to be.
final quizCatalogueProvider = Provider<Set<String>>((ref) {
  final corpus = ref.watch(corpusProvider).value;
  if (corpus == null) return const <String>{};
  return QuizBuilder.factsFor(
    corpus,
    corpus.allEntities.map((entity) => entity.ref).toSet(),
  );
});

/// Where the reader stands on the ladder.
final readerRankProvider = Provider<ReaderRank>((ref) {
  final total = ref.watch(quizCatalogueProvider).length;
  final mastered = ref.watch(
    libraryProvider.select((library) => library.masteredFacts.length),
  );
  return ReaderRank(mastered: mastered, total: total);
});

/// A reader's standing, as the home screen needs it.
class ReaderRank {
  const ReaderRank({required this.mastered, required this.total});

  /// Facts answered correctly.
  final int mastered;

  /// Facts there are.
  final int total;

  /// The rank index, from zero.
  int get level => Ranks.levelFor(mastered, total);

  /// The rank number a reader sees, which counts from one.
  int get displayLevel => level + 1;

  /// How far into this rank they are, from 0 to 1.
  double get progress => Ranks.progressWithin(mastered, total);

  /// How many more facts to the next rank, or `null` at the top.
  int? get toNext => Ranks.factsToNext(mastered, total);

  /// Whether there is nothing left to climb.
  bool get isTop => level >= Ranks.top;
}

/// The notes on a given article.
final notesForProvider = Provider.family<List<Note>, EntityRef>(
  (ref, target) =>
      ref.watch(libraryProvider.select((library) => library.notesFor(target))),
);
