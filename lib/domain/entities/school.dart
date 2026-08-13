import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// A school, movement or tradition of thought.
///
/// Schools are treated as entities in their own right rather than as tags,
/// because a reader can sensibly ask what Stoicism held, when it ran, who
/// belonged to it and what it was arguing against — and none of those questions
/// can be answered by a label.
class School implements KnowledgeEntity {
  const School({
    required this.id,
    required this.name,
    required this.oneLine,
    this.nativeName,
    this.transliteration,
    this.alsoKnownAs = const <String>[],
    this.period,
    this.traditions = const <Tradition>{},
    this.branches = const <PhilosophyBranch>{},
    this.article = Article.empty,
    this.centralClaims = const <LocalizedText>[],
    this.memberIds = const <String>[],
    this.founderIds = const <String>[],
    this.conceptIds = const <String>[],
    this.opposedSchoolIds = const <String>[],
    this.citations = const <Citation>[],
  });

  @override
  final String id;

  @override
  final LocalizedText name;

  @override
  final LocalizedText oneLine;

  /// The name in its original script, e.g. `Στοά`, `حکمت متعالیه`.
  final String? nativeName;

  /// A Latin-letter transliteration of [nativeName].
  final String? transliteration;

  /// Other names the school is known by.
  final List<String> alsoKnownAs;

  /// When the school was active. Open-ended for schools with living
  /// descendants.
  final HistoricalRange? period;

  @override
  final Set<Tradition> traditions;

  @override
  final Set<PhilosophyBranch> branches;

  @override
  final Article article;

  /// The positions that make someone a member of this school, stated as claims
  /// a reader can agree or disagree with.
  final List<LocalizedText> centralClaims;

  /// Philosophers belonging to the school.
  final List<String> memberIds;

  /// Those who founded it.
  final List<String> founderIds;

  /// Concepts the school is built around.
  final List<String> conceptIds;

  /// Schools it defined itself against.
  final List<String> opposedSchoolIds;

  @override
  final List<Citation> citations;

  @override
  EntityRef get ref => EntityRef(EntityKind.school, id);

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
  bool operator ==(Object other) => other is School && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'School($id, ${name.en})';
}
