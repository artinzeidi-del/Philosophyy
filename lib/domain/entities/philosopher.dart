import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// What became of a philosopher's own writing.
///
/// ## Why this is recorded rather than inferred
///
/// A page that simply omits the works section when there are none tells the
/// reader nothing about why. Socrates wrote nothing on principle; Hypatia's
/// commentaries were destroyed; Heraclitus wrote a book that no one has seen
/// since antiquity. Those are three different facts, and all three of them are
/// part of what a reader should know about the person — but an empty section
/// reads as an unfinished app in every case.
///
/// So the absence is stated. The alternative is for the reference to look
/// incomplete exactly where it is being accurate.
enum Writings {
  /// At least one work survives as a work and can be read.
  extant,

  /// They left nothing in writing, or nothing that outlasted them. What is
  /// known comes through other people.
  none,

  /// Only passages quoted by later writers survive. There is no book of theirs
  /// to read, and any account of their thought is assembled from those
  /// quotations.
  fragments,
}

/// A philosopher.
///
/// Names are held three ways — [name] for display, [nativeName] in the original
/// script, and [transliteration] in Latin letters — because a reader may arrive
/// looking for `ابن‌سینا`, `Ibn Sina` or `Avicenna`, and a reference work that
/// finds the person under only one of those is failing two thirds of its
/// readers.
class Philosopher implements KnowledgeEntity {
  const Philosopher({
    required this.id,
    required this.name,
    required this.oneLine,
    required this.life,
    this.nativeName,
    this.transliteration,
    this.alsoKnownAs = const <String>[],
    this.birthPlace,
    this.deathPlace,
    this.traditions = const <String>{},
    this.branches = const <String>{},
    this.article = Article.empty,
    this.conceptIds = const <String>[],
    this.schoolIds = const <String>[],
    this.citations = const <Citation>[],
    this.writings = Writings.extant,
  });

  @override
  final String id;

  @override
  final LocalizedText name;

  @override
  final LocalizedText oneLine;

  /// The name in its original script, e.g. `Πλάτων`, `ابن‌سینا`, `孔子`.
  final String? nativeName;

  /// A Latin-letter transliteration of [nativeName], where the display [name]
  /// is not already one.
  final String? transliteration;

  /// Other names the person is commonly found under, including Latinisations
  /// and historical variants.
  final List<String> alsoKnownAs;

  /// When the person lived.
  final LifeSpan life;

  /// Where they were born, when known.
  final LocalizedText? birthPlace;

  /// Where they died, when known.
  final LocalizedText? deathPlace;

  @override
  final Set<String> traditions;

  @override
  final Set<String> branches;

  @override
  final Article article;

  /// Concepts this philosopher originated or is central to.
  final List<String> conceptIds;

  /// What became of their writing. See [Writings].
  final Writings writings;

  /// Schools they belonged to or founded.
  final List<String> schoolIds;

  @override
  final List<Citation> citations;

  @override
  EntityRef get ref => EntityRef(EntityKind.philosopher, id);

  /// The year used to place this philosopher on a timeline.
  HistoricalYear? get timelineAnchor => life.sortAnchor;

  @override
  Iterable<String> get searchableStrings sync* {
    yield* name.allVariants;
    final native = nativeName;
    if (native != null) yield native;
    final latin = transliteration;
    if (latin != null) yield latin;
    yield* alsoKnownAs;
    yield* oneLine.allVariants;
  }

  @override
  bool operator ==(Object other) => other is Philosopher && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Philosopher($id, ${name.en})';
}
