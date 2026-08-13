import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// A reader's saved entry.
///
/// Bookmarks carry no content of their own — they point at an article. That
/// keeps them valid when an entry is rewritten, and means a bookmark can never
/// go stale in the way a copied excerpt can.
class Bookmark implements Comparable<Bookmark> {
  const Bookmark({required this.target, required this.savedAt});

  /// The article that was saved.
  final EntityRef target;

  /// When the reader saved it.
  final DateTime savedAt;

  @override
  int compareTo(Bookmark other) => other.savedAt.compareTo(savedAt);

  @override
  bool operator ==(Object other) => other is Bookmark && other.target == target;

  @override
  int get hashCode => target.hashCode;

  @override
  String toString() => 'Bookmark($target)';
}

/// Something the reader wrote.
///
/// A note may be attached to a whole article or to one section of it. It is the
/// reader's own words and is never rewritten by the app — content updates change
/// what a note sits beside, never the note.
class Note implements Comparable<Note> {
  const Note({
    required this.id,
    required this.target,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.sectionId,
  });

  /// Identifier, unique across the reader's notes.
  final String id;

  /// The article this note belongs to.
  final EntityRef target;

  /// The section it is anchored to, or `null` for a note on the whole article.
  final String? sectionId;

  /// The reader's text.
  final String body;

  /// When it was first written.
  final DateTime createdAt;

  /// When it was last edited.
  final DateTime updatedAt;

  /// Whether the note has been edited since it was written.
  bool get isEdited => updatedAt.isAfter(createdAt);

  /// Returns a copy with new text and an updated timestamp.
  Note withBody(String newBody, {required DateTime at}) => Note(
    id: id,
    target: target,
    sectionId: sectionId,
    body: newBody,
    createdAt: createdAt,
    updatedAt: at,
  );

  @override
  int compareTo(Note other) => other.updatedAt.compareTo(updatedAt);

  @override
  bool operator ==(Object other) => other is Note && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Note($id on $target)';
}

/// A passage the reader marked.
///
/// ## Why the excerpt is stored alongside the offsets
///
/// [start] and [end] index into the section's text as it was when the reader
/// made the mark. Content is edited — a sentence is corrected, a paragraph is
/// expanded — and when it is, those offsets silently point at the wrong words.
/// Storing [excerpt] means the app can detect the drift (the text at the offsets
/// no longer matches), re-find the passage if it still exists, and otherwise
/// show the reader what they marked rather than a wrong span or nothing at all.
///
/// This is the difference between a highlight that survives the corpus being
/// improved and one that quietly corrupts.
class Highlight implements Comparable<Highlight> {
  const Highlight({
    required this.id,
    required this.target,
    required this.sectionId,
    required this.start,
    required this.end,
    required this.excerpt,
    required this.createdAt,
  }) : assert(start >= 0, 'a highlight cannot start before the text'),
       assert(end > start, 'a highlight must cover at least one character');

  /// Identifier, unique across the reader's highlights.
  final String id;

  /// The article the passage is in.
  final EntityRef target;

  /// The section the passage is in.
  final String sectionId;

  /// Character offset where the passage begins.
  final int start;

  /// Character offset just past where it ends.
  final int end;

  /// The marked text as it read when the mark was made.
  final String excerpt;

  /// When the reader marked it.
  final DateTime createdAt;

  /// How many characters are covered.
  int get length => end - start;

  /// Whether [sectionText] still contains this highlight where it was left.
  bool isAnchoredIn(String sectionText) {
    if (end > sectionText.length) return false;
    return sectionText.substring(start, end) == excerpt;
  }

  /// Re-finds this highlight in [sectionText] after the text has changed.
  ///
  /// Returns a highlight with corrected offsets when the excerpt still occurs
  /// exactly once, and `null` when the passage has gone or become ambiguous —
  /// in which case the caller should keep the reader's excerpt and tell them it
  /// no longer matches, rather than guessing.
  Highlight? reanchoredIn(String sectionText) {
    if (isAnchoredIn(sectionText)) return this;
    final first = sectionText.indexOf(excerpt);
    if (first < 0) return null;
    if (sectionText.indexOf(excerpt, first + 1) >= 0) return null;
    return Highlight(
      id: id,
      target: target,
      sectionId: sectionId,
      start: first,
      end: first + excerpt.length,
      excerpt: excerpt,
      createdAt: createdAt,
    );
  }

  @override
  int compareTo(Highlight other) {
    final bySection = sectionId.compareTo(other.sectionId);
    return bySection != 0 ? bySection : start.compareTo(other.start);
  }

  @override
  bool operator ==(Object other) => other is Highlight && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Highlight($id, $target#$sectionId [$start,$end))';
}

/// Where the reader had got to in an article.
class ReadingPosition {
  const ReadingPosition({
    required this.target,
    required this.scrollOffset,
    required this.updatedAt,
    this.sectionId,
  });

  /// The article.
  final EntityRef target;

  /// The section that was on screen, when one could be identified.
  final String? sectionId;

  /// How far down the article the reader had scrolled, in logical pixels.
  final double scrollOffset;

  /// When the position was recorded.
  final DateTime updatedAt;

  /// Whether this position is far enough in to be worth restoring.
  ///
  /// Returning a reader to the top of an article they barely opened is not a
  /// service, and it costs them the scroll they would otherwise have kept.
  bool get isWorthRestoring => scrollOffset > 200;

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition && other.target == target;

  @override
  int get hashCode => target.hashCode;

  @override
  String toString() => 'ReadingPosition($target @ $scrollOffset)';
}

/// Everything the reader owns, held together.
///
/// This is a value: every mutation returns a new library rather than editing in
/// place, which makes the repository's job a straight save of whatever it is
/// handed, and makes state changes obvious to the UI layer.
class UserLibrary {
  const UserLibrary({
    this.bookmarks = const <Bookmark>[],
    this.notes = const <Note>[],
    this.highlights = const <Highlight>[],
    this.positions = const <ReadingPosition>[],
  });

  /// A reader who has saved nothing yet.
  static const UserLibrary empty = UserLibrary();

  /// Saved articles.
  final List<Bookmark> bookmarks;

  /// Written notes.
  final List<Note> notes;

  /// Marked passages.
  final List<Highlight> highlights;

  /// Reading positions, at most one per article.
  final List<ReadingPosition> positions;

  /// Whether the reader has saved anything at all.
  bool get isEmpty =>
      bookmarks.isEmpty &&
      notes.isEmpty &&
      highlights.isEmpty &&
      positions.isEmpty;

  /// How many things the reader has created, excluding reading positions —
  /// which they did not choose to create.
  int get itemCount => bookmarks.length + notes.length + highlights.length;

  /// Whether [ref] is bookmarked.
  bool isBookmarked(EntityRef ref) =>
      bookmarks.any((bookmark) => bookmark.target == ref);

  /// Notes on [ref], most recently edited first.
  List<Note> notesFor(EntityRef ref) =>
      notes.where((note) => note.target == ref).toList()..sort();

  /// Highlights in [ref], in reading order.
  List<Highlight> highlightsFor(EntityRef ref) =>
      highlights.where((highlight) => highlight.target == ref).toList()..sort();

  /// Highlights in one section of [ref], in reading order.
  List<Highlight> highlightsIn(EntityRef ref, String sectionId) =>
      highlights
          .where(
            (highlight) =>
                highlight.target == ref && highlight.sectionId == sectionId,
          )
          .toList()
        ..sort();

  /// The saved reading position for [ref], if any.
  ReadingPosition? positionFor(EntityRef ref) {
    for (final position in positions) {
      if (position.target == ref) return position;
    }
    return null;
  }

  /// Every article the reader has touched in any way, most recent first.
  ///
  /// This is what a library screen shows: not just bookmarks, but everything
  /// they have engaged with, because a reader who annotated an article without
  /// bookmarking it still expects to find it again.
  List<EntityRef> get touchedTargets {
    final latest = <EntityRef, DateTime>{};

    void record(EntityRef ref, DateTime at) {
      final existing = latest[ref];
      if (existing == null || at.isAfter(existing)) latest[ref] = at;
    }

    for (final bookmark in bookmarks) {
      record(bookmark.target, bookmark.savedAt);
    }
    for (final note in notes) {
      record(note.target, note.updatedAt);
    }
    for (final highlight in highlights) {
      record(highlight.target, highlight.createdAt);
    }
    for (final position in positions) {
      record(position.target, position.updatedAt);
    }

    final ordered = latest.keys.toList()
      ..sort((a, b) => latest[b]!.compareTo(latest[a]!));
    return ordered;
  }

  /// Adds or removes a bookmark on [ref].
  UserLibrary toggleBookmark(EntityRef ref, {required DateTime at}) =>
      isBookmarked(ref)
      ? copyWith(
          bookmarks: bookmarks
              .where((bookmark) => bookmark.target != ref)
              .toList(),
        )
      : copyWith(
          bookmarks: <Bookmark>[
            Bookmark(target: ref, savedAt: at),
            ...bookmarks,
          ],
        );

  /// Adds a note, or replaces one with the same identifier.
  UserLibrary withNote(Note note) => copyWith(
    notes: <Note>[note, ...notes.where((existing) => existing.id != note.id)],
  );

  /// Removes a note.
  UserLibrary withoutNote(String noteId) =>
      copyWith(notes: notes.where((note) => note.id != noteId).toList());

  /// Adds a highlight, or replaces one with the same identifier.
  UserLibrary withHighlight(Highlight highlight) => copyWith(
    highlights: <Highlight>[
      highlight,
      ...highlights.where((existing) => existing.id != highlight.id),
    ],
  );

  /// Removes a highlight.
  UserLibrary withoutHighlight(String highlightId) => copyWith(
    highlights: highlights
        .where((highlight) => highlight.id != highlightId)
        .toList(),
  );

  /// Records where the reader had got to, replacing any earlier position for
  /// the same article.
  UserLibrary withPosition(ReadingPosition position) => copyWith(
    positions: <ReadingPosition>[
      position,
      ...positions.where((existing) => existing.target != position.target),
    ],
  );

  /// Removes everything belonging to [ref] — used when a reader clears an
  /// article, and when content is removed from the corpus.
  UserLibrary withoutTarget(EntityRef ref) => UserLibrary(
    bookmarks: bookmarks.where((it) => it.target != ref).toList(),
    notes: notes.where((it) => it.target != ref).toList(),
    highlights: highlights.where((it) => it.target != ref).toList(),
    positions: positions.where((it) => it.target != ref).toList(),
  );

  /// Returns a copy with the given collections replaced.
  UserLibrary copyWith({
    List<Bookmark>? bookmarks,
    List<Note>? notes,
    List<Highlight>? highlights,
    List<ReadingPosition>? positions,
  }) => UserLibrary(
    bookmarks: bookmarks ?? this.bookmarks,
    notes: notes ?? this.notes,
    highlights: highlights ?? this.highlights,
    positions: positions ?? this.positions,
  );

  @override
  String toString() =>
      'UserLibrary(${bookmarks.length} bookmarks, ${notes.length} notes, '
      '${highlights.length} highlights, ${positions.length} positions)';
}
