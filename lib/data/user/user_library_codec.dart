import 'dart:convert';

import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// Raised when a stored library cannot be read.
class LibraryFormatException implements Exception {
  const LibraryFormatException(this.message, {this.cause});

  /// What went wrong.
  final String message;

  /// The underlying error, when this wraps one.
  final Object? cause;

  @override
  String toString() =>
      'LibraryFormatException: $message'
      '${cause == null ? '' : ' (caused by: $cause)'}';
}

/// Reads and writes the reader's library as JSON.
///
/// ## Versioning
///
/// Every stored document carries [currentVersion]. On read, a document from an
/// older version is passed through [_migrate] before being parsed; a document
/// from a *newer* version is refused outright rather than parsed on a hopeful
/// basis, because the one thing worse than failing to read a reader's notes is
/// reading them wrongly and then saving the damage back.
///
/// ## What happens to data that cannot be read
///
/// Nothing is ever silently discarded. [decode] throws, and the repository
/// responds by setting the unreadable document aside under a salvage key and
/// starting the reader with an empty library. That way a bug here costs a reader
/// their notes temporarily rather than permanently, and the original bytes are
/// still on the device to be recovered.
abstract final class UserLibraryCodec {
  /// The schema version this build writes.
  static const int currentVersion = 2;

  /// Serialises [library] to a JSON document.
  static String encode(UserLibrary library) => jsonEncode(<String, Object?>{
    'version': currentVersion,
    'bookmarks': <Object?>[
      for (final bookmark in library.bookmarks)
        <String, Object?>{
          'target': bookmark.target.canonical,
          'savedAt': bookmark.savedAt.toUtc().toIso8601String(),
        },
    ],
    'notes': <Object?>[
      for (final note in library.notes)
        <String, Object?>{
          'id': note.id,
          'target': note.target.canonical,
          if (note.sectionId != null) 'sectionId': note.sectionId,
          'body': note.body,
          'createdAt': note.createdAt.toUtc().toIso8601String(),
          'updatedAt': note.updatedAt.toUtc().toIso8601String(),
        },
    ],
    'highlights': <Object?>[
      for (final highlight in library.highlights)
        <String, Object?>{
          'id': highlight.id,
          'target': highlight.target.canonical,
          'sectionId': highlight.sectionId,
          'start': highlight.start,
          'end': highlight.end,
          'excerpt': highlight.excerpt,
          'createdAt': highlight.createdAt.toUtc().toIso8601String(),
        },
    ],
    'positions': <Object?>[
      for (final position in library.positions)
        <String, Object?>{
          'target': position.target.canonical,
          if (position.sectionId != null) 'sectionId': position.sectionId,
          'scrollOffset': position.scrollOffset,
          'updatedAt': position.updatedAt.toUtc().toIso8601String(),
        },
    ],
    'readMarks': <Object?>[
      for (final mark in library.readMarks)
        <String, Object?>{
          'target': mark.target.canonical,
          'markedAt': mark.markedAt.toUtc().toIso8601String(),
        },
    ],
  });

  /// Parses a stored document.
  ///
  /// Throws [LibraryFormatException] when the document cannot be trusted.
  static UserLibrary decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw LibraryFormatException('not valid JSON', cause: error);
    }

    if (decoded is! Map<String, Object?>) {
      throw const LibraryFormatException('expected a JSON object at the root');
    }

    final version = decoded['version'];
    if (version is! int) {
      throw const LibraryFormatException('missing or malformed version');
    }
    if (version > currentVersion) {
      throw LibraryFormatException(
        'written by a newer version of the app (found $version, this build '
        'understands $currentVersion). Refusing to guess at its meaning.',
      );
    }

    final document = _migrate(decoded, from: version);

    try {
      return UserLibrary(
        bookmarks: _list(document, 'bookmarks', _bookmark),
        notes: _list(document, 'notes', _note),
        highlights: _list(document, 'highlights', _highlight),
        positions: _list(document, 'positions', _position),
        readMarks: _list(document, 'readMarks', _readMark),
      );
    } on LibraryFormatException {
      rethrow;
    } on Object catch (error) {
      throw LibraryFormatException('could not be read', cause: error);
    }
  }

  /// Brings an older document up to the current schema.
  ///
  /// Each step is a separate `if`, applied in order, so that a document two
  /// versions behind is carried forward through every intermediate shape rather
  /// than jumped straight to the newest — which is how migrations quietly stop
  /// working for the readers who upgrade least often.
  static Map<String, Object?> _migrate(
    Map<String, Object?> document, {
    required int from,
  }) {
    var migrated = document;
    var at = from;

    // 1→2 added the marks a reader puts on articles they have finished.
    // Nothing in version 1 changes shape, so the step is to supply the absent
    // list — spelled out rather than left to `_list` tolerating a missing key,
    // because a migration that does nothing visible is one nobody can check.
    if (at == 1) {
      migrated = <String, Object?>{
        ...migrated,
        'readMarks': const <Object?>[],
        'version': 2,
      };
      at = 2;
    }

    // Each further step goes here, one at a time, so that a reader who upgrades
    // rarely is carried through every intermediate shape rather than jumped to
    // the newest. Each must come with a test that migrates a populated document
    // forward and asserts nothing was lost: this is the reader's own writing,
    // and losing it is not an acceptable outcome of an app update.
    if (at != currentVersion) {
      throw LibraryFormatException(
        'no migration path from version $from to $currentVersion',
      );
    }
    return migrated;
  }

  static List<T> _list<T>(
    Map<String, Object?> document,
    String field,
    T Function(Map<String, Object?>) parse,
  ) {
    final value = document[field];
    if (value == null) return <T>[];
    if (value is! List) {
      throw LibraryFormatException('"$field" is not an array');
    }
    return <T>[
      for (final element in value)
        if (element is Map<String, Object?>)
          parse(element)
        else
          throw LibraryFormatException('"$field" holds a non-object entry'),
    ];
  }

  static EntityRef _ref(Map<String, Object?> json, String field) {
    final raw = json[field];
    if (raw is! String) {
      throw LibraryFormatException('"$field" is missing');
    }
    final ref = EntityRef.tryParse(raw);
    if (ref == null) {
      throw LibraryFormatException('"$raw" is not a valid reference');
    }
    return ref;
  }

  static DateTime _time(Map<String, Object?> json, String field) {
    final raw = json[field];
    if (raw is! String) {
      throw LibraryFormatException('"$field" is missing');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw LibraryFormatException('"$raw" is not a valid timestamp');
    }
    return parsed;
  }

  static String _text(Map<String, Object?> json, String field) {
    final raw = json[field];
    if (raw is! String) {
      throw LibraryFormatException('"$field" is missing');
    }
    return raw;
  }

  static int _integer(Map<String, Object?> json, String field) {
    final raw = json[field];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    throw LibraryFormatException('"$field" is not a number');
  }

  static ReadMark _readMark(Map<String, Object?> json) =>
      ReadMark(target: _ref(json, 'target'), markedAt: _time(json, 'markedAt'));

  static Bookmark _bookmark(Map<String, Object?> json) =>
      Bookmark(target: _ref(json, 'target'), savedAt: _time(json, 'savedAt'));

  static Note _note(Map<String, Object?> json) => Note(
    id: _text(json, 'id'),
    target: _ref(json, 'target'),
    sectionId: json['sectionId'] as String?,
    body: _text(json, 'body'),
    createdAt: _time(json, 'createdAt'),
    updatedAt: _time(json, 'updatedAt'),
  );

  static Highlight _highlight(Map<String, Object?> json) {
    final start = _integer(json, 'start');
    final end = _integer(json, 'end');
    if (start < 0 || end <= start) {
      throw LibraryFormatException('highlight span [$start, $end) is invalid');
    }
    return Highlight(
      id: _text(json, 'id'),
      target: _ref(json, 'target'),
      sectionId: _text(json, 'sectionId'),
      start: start,
      end: end,
      excerpt: _text(json, 'excerpt'),
      createdAt: _time(json, 'createdAt'),
    );
  }

  static ReadingPosition _position(Map<String, Object?> json) {
    final offset = json['scrollOffset'];
    return ReadingPosition(
      target: _ref(json, 'target'),
      sectionId: json['sectionId'] as String?,
      scrollOffset: offset is num ? offset.toDouble() : 0,
      updatedAt: _time(json, 'updatedAt'),
    );
  }
}
