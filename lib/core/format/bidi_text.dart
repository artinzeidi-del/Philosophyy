/// Keeping foreign runs from being rearranged inside a right-to-left line.
///
/// ## The defect this exists for
///
/// A citation on Nietzsche's page read «فریدریش نیچه · حکمت شاداب · 125§».
/// The content says `§125`, which is what a reader looking for the passage
/// needs; what they were shown was `125§`, which is not a section number in
/// any edition.
///
/// Nothing was wrong with the data. The Unicode bidirectional algorithm
/// resolves each run of text by its own characters, and `§` has no direction
/// of its own — so inside a Persian paragraph it takes the paragraph's
/// direction and lands to the right of the digits, which are always
/// left-to-right. The same happens to a page range, a Stephanus number, a
/// transliteration: anything neutral or Latin that is dropped into a Persian
/// sentence.
///
/// ## Why the digits are not converted
///
/// The obvious alternative is to render `§۱۲۵` in Persian digits, and it is
/// wrong. A locator is not a quantity; it is an index into one edition's
/// numbering. `A51/B75` points at two pages of two printings of Kant, `1098a`
/// is a line of the Bekker text, `368d` a column of Stephanus. A reader takes
/// those characters to a book or a search box, and Persian digits would make
/// them fail there. Dates and counts are quantities and are localised; these
/// are identifiers and are not.
library;

/// The isolate markers, written as escapes rather than as themselves.
///
/// An invisible character in a source file is how this defect reached the
/// product in the first place; it should not also be how the fix is written.
const String _firstStrongIsolate = '\u2068';
const String _popDirectionalIsolate = '\u2069';

/// Wraps [text] so the bidirectional algorithm resolves it on its own.
///
/// U+2068 opens a first-strong isolate — the run's direction is taken from its
/// first strong character rather than from the paragraph — and U+2069 closes
/// it. Unlike the older embedding marks, an isolate also stops the run from
/// affecting the order of what surrounds it.
///
/// Returns [text] unchanged when it is empty, so callers can apply it without
/// checking first and an empty string does not acquire two invisible
/// characters.
String isolateBidi(String text) =>
    text.isEmpty ? text : '$_firstStrongIsolate$text$_popDirectionalIsolate';

/// Joins [parts] for display, isolating each one.
///
/// Citation lines are built by joining an author, a title and a locator with a
/// separator, and every one of those can be in a different script from the
/// line around it. Isolating each part means the separator stays between them
/// in reading order whatever they contain.
String joinIsolated(Iterable<String> parts, String separator) =>
    parts.map(isolateBidi).join(separator);
