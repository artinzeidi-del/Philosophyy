import 'package:philosophyy/core/errors/content_exception.dart';

/// A cursor over a decoded JSON object that reports where a problem is.
///
/// Hand-written `map['x'] as String` casts produce errors that say a type was
/// wrong but not which record it was in, which is useless against a content
/// file with two hundred entries. Every accessor here threads a [path] through,
/// so a failure names the exact field.
///
/// Accessors come in two forms throughout: `required*` throws when the field is
/// missing, and the plain form returns `null`. Optional fields must never be
/// silently defaulted — a philosopher with no recorded birth year and one whose
/// birth year was forgotten by an editor are different situations, and only the
/// first should reach the app.
class JsonReader {
  const JsonReader(this._json, {required this.path, this.file});

  /// Wraps a decoded top-level document.
  factory JsonReader.root(Object? decoded, {required String file}) {
    if (decoded is! Map<String, Object?>) {
      throw ContentException(
        message:
            'expected the document root to be a JSON object, '
            'found ${decoded.runtimeType}',
        path: r'$',
        file: file,
      );
    }
    return JsonReader(decoded, path: r'$', file: file);
  }

  final Map<String, Object?> _json;

  /// Where this object sits in the document.
  final String path;

  /// Which file the object came from.
  final String? file;

  Never _fail(String message, {String? field, Object? cause}) {
    throw ContentException(
      message: message,
      path: field == null ? path : '$path.$field',
      file: file,
      cause: cause,
    );
  }

  /// Whether [field] is present and not null.
  bool has(String field) => _json[field] != null;

  /// A required string.
  String requiredString(String field) {
    final value = _json[field];
    if (value == null) _fail('missing required field', field: field);
    if (value is! String) {
      _fail('expected a string, found ${value.runtimeType}', field: field);
    }
    if (value.trim().isEmpty) _fail('must not be blank', field: field);
    return value;
  }

  /// An optional string. Blank strings are rejected rather than accepted as
  /// empty, because a blank field in authored content is always a mistake.
  String? string(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is! String) {
      _fail('expected a string, found ${value.runtimeType}', field: field);
    }
    if (value.trim().isEmpty) {
      _fail('is present but blank; omit it instead', field: field);
    }
    return value;
  }

  /// A required integer.
  int requiredInt(String field) {
    final value = _json[field];
    if (value == null) _fail('missing required field', field: field);
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    _fail('expected an integer, found ${value.runtimeType}', field: field);
  }

  /// An optional integer.
  int? integer(String field) =>
      _json[field] == null ? null : requiredInt(field);

  /// An optional boolean.
  bool boolean(String field, {required bool orElse}) {
    final value = _json[field];
    if (value == null) return orElse;
    if (value is! bool) {
      _fail('expected a boolean, found ${value.runtimeType}', field: field);
    }
    return value;
  }

  /// A required nested object.
  JsonReader requiredObject(String field) {
    final value = _json[field];
    if (value == null) _fail('missing required field', field: field);
    return _object(field, value);
  }

  /// An optional nested object.
  JsonReader? object(String field) {
    final value = _json[field];
    if (value == null) return null;
    return _object(field, value);
  }

  JsonReader _object(String field, Object? value) {
    if (value is! Map<String, Object?>) {
      _fail('expected an object, found ${value.runtimeType}', field: field);
    }
    return JsonReader(value, path: '$path.$field', file: file);
  }

  /// A list of strings, defaulting to empty when the field is absent.
  List<String> stringList(String field) {
    final value = _json[field];
    if (value == null) return const <String>[];
    if (value is! List) {
      _fail('expected an array, found ${value.runtimeType}', field: field);
    }
    return List<String>.generate(value.length, (index) {
      final element = value[index];
      if (element is! String || element.trim().isEmpty) {
        _fail(
          'expected a non-blank string at index $index, '
          'found ${element.runtimeType}',
          field: field,
        );
      }
      return element;
    });
  }

  /// A list of nested objects, defaulting to empty when the field is absent.
  List<JsonReader> objectList(String field) {
    final value = _json[field];
    if (value == null) return const <JsonReader>[];
    if (value is! List) {
      _fail('expected an array, found ${value.runtimeType}', field: field);
    }
    return List<JsonReader>.generate(value.length, (index) {
      final element = value[index];
      if (element is! Map<String, Object?>) {
        _fail(
          'expected an object at index $index, found ${element.runtimeType}',
          field: field,
        );
      }
      return JsonReader(element, path: '$path.$field[$index]', file: file);
    });
  }

  /// Maps a required string field through [lookup], failing with the list of
  /// permitted values when the stored identifier is not one of them.
  ///
  /// Content files are hand-authored, so a typo in an enumerated value is the
  /// single most likely content error. Naming the valid options in the message
  /// turns a puzzle into a one-line fix.
  T requiredEnum<T>(
    String field,
    T? Function(String) lookup,
    Iterable<String> permitted,
  ) {
    final raw = requiredString(field);
    final parsed = lookup(raw);
    if (parsed == null) {
      _fail(
        'unknown value "$raw"; expected one of: ${permitted.join(', ')}',
        field: field,
      );
    }
    return parsed;
  }

  /// The optional form of [requiredEnum].
  T? optionalEnum<T>(
    String field,
    T? Function(String) lookup,
    Iterable<String> permitted,
  ) => _json[field] == null ? null : requiredEnum(field, lookup, permitted);

  /// Maps a string array through [lookup] into a set.
  Set<T> enumSet<T>(
    String field,
    T? Function(String) lookup,
    Iterable<String> permitted,
  ) {
    final raw = stringList(field);
    final parsed = <T>{};
    for (var index = 0; index < raw.length; index++) {
      final value = lookup(raw[index]);
      if (value == null) {
        _fail(
          'unknown value "${raw[index]}" at index $index; '
          'expected one of: ${permitted.join(', ')}',
          field: field,
        );
      }
      parsed.add(value);
    }
    return parsed;
  }

  /// Reports a violation of a rule this reader cannot express structurally.
  Never invalid(String message, {String? field}) =>
      _fail(message, field: field);
}
