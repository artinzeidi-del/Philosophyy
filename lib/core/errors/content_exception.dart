/// Raised when bundled content cannot be read as the domain requires.
///
/// Content ships with the app, so a malformed record is a build-time defect
/// that escaped review rather than anything a reader did. The exception
/// therefore carries the exact [path] into the document — `philosophers[3].life`
/// rather than "invalid input" — because the person who has to act on it is a
/// developer or an editor, and a message that does not locate the problem
/// wastes their time.
///
/// This is deliberately never shown to a reader. The presentation layer turns
/// it into a plain apology and a way out; the detail goes to the log.
class ContentException implements Exception {
  const ContentException({
    required this.message,
    required this.path,
    this.file,
    this.cause,
  });

  /// What is wrong, in developer-facing language.
  final String message;

  /// Where in the document the problem is, e.g. `philosophers[3].life.birth`.
  final String path;

  /// Which content file the problem is in.
  final String? file;

  /// The underlying error, when this wraps one.
  final Object? cause;

  @override
  String toString() {
    final location = file == null ? path : '$file → $path';
    final because = cause == null ? '' : ' (caused by: $cause)';
    return 'ContentException at $location: $message$because';
  }
}

/// Raised when content parses but violates an integrity rule — a relation
/// pointing at an entity that does not exist, a quotation claiming verification
/// with no citation, a work attributed to an unknown author.
///
/// Kept separate from [ContentException] because the two call for different
/// responses: a parse failure means the file is broken, while an integrity
/// failure means the content is internally inconsistent and needs an editor.
class ContentIntegrityException implements Exception {
  const ContentIntegrityException(this.violations);

  /// Every violation found, so one run reports all of them rather than making
  /// an editor fix them one at a time.
  final List<String> violations;

  @override
  String toString() =>
      'ContentIntegrityException: ${violations.length} violation(s)\n'
      '${violations.map((violation) => '  • $violation').join('\n')}';
}
