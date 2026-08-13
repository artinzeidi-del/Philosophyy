import 'package:philosophyy/core/errors/content_exception.dart';
import 'package:philosophyy/domain/entities/argument.dart';
import 'package:philosophyy/domain/entities/concept.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/school.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/entities/work.dart';

import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// The whole corpus, in memory, with the graph indexed for traversal.
///
/// The content is small enough to hold entirely in memory and will remain so
/// for a long time; loading it once and querying it synchronously removes an
/// enormous amount of asynchronous plumbing from the layers above, and makes
/// every screen's data access a plain function call. When the corpus outgrows
/// this — the threshold is roughly when load time becomes perceptible on a low
/// end phone — the repository interface stays the same and only this class is
/// replaced by a database-backed one.
class KnowledgeBase {
  KnowledgeBase({
    required List<Philosopher> philosophers,
    required List<Concept> concepts,
    required List<Work> works,
    required List<School> schools,
    required List<Quote> quotes,
    required List<Argument> arguments,
    required List<Source> sources,
    required List<Relation> relations,
  }) : philosophers = List.unmodifiable(philosophers),
       concepts = List.unmodifiable(concepts),
       works = List.unmodifiable(works),
       schools = List.unmodifiable(schools),
       quotes = List.unmodifiable(quotes),
       arguments = List.unmodifiable(arguments),
       sources = List.unmodifiable(sources),
       relations = List.unmodifiable(relations),
       _philosophersById = {for (final it in philosophers) it.id: it},
       _conceptsById = {for (final it in concepts) it.id: it},
       _worksById = {for (final it in works) it.id: it},
       _schoolsById = {for (final it in schools) it.id: it},
       _quotesById = {for (final it in quotes) it.id: it},
       _argumentsById = {for (final it in arguments) it.id: it},
       _sourcesById = {for (final it in sources) it.id: it} {
    _indexRelations();
  }

  /// An empty corpus, used as a loading placeholder and in tests.
  static final KnowledgeBase empty = KnowledgeBase(
    philosophers: const [],
    concepts: const [],
    works: const [],
    schools: const [],
    quotes: const [],
    arguments: const [],
    sources: const [],
    relations: const [],
  );

  /// All philosophers, in the order they were authored.
  final List<Philosopher> philosophers;

  /// All concepts.
  final List<Concept> concepts;

  /// All works.
  final List<Work> works;

  /// All schools.
  final List<School> schools;

  /// All quotations.
  final List<Quote> quotes;

  /// All reconstructed arguments.
  final List<Argument> arguments;

  /// All bibliographic sources.
  final List<Source> sources;

  /// Every authored relation, in the direction it was authored.
  final List<Relation> relations;

  final Map<String, Philosopher> _philosophersById;
  final Map<String, Concept> _conceptsById;
  final Map<String, Work> _worksById;
  final Map<String, School> _schoolsById;
  final Map<String, Quote> _quotesById;
  final Map<String, Argument> _argumentsById;
  final Map<String, Source> _sourcesById;

  /// Adjacency: every relation touching a given entity, already oriented so
  /// the entity is the subject.
  final Map<EntityRef, List<Relation>> _adjacency =
      <EntityRef, List<Relation>>{};

  void _indexRelations() {
    for (final relation in relations) {
      _adjacency
          .putIfAbsent(relation.subject, () => <Relation>[])
          .add(relation);
      // A symmetric relation reads the same from both ends, so storing the
      // inverted copy would show the reader the same edge twice.
      if (!relation.type.isSymmetric) {
        _adjacency
            .putIfAbsent(relation.object, () => <Relation>[])
            .add(relation.inverted);
      } else {
        _adjacency
            .putIfAbsent(relation.object, () => <Relation>[])
            .add(
              Relation(
                subject: relation.object,
                type: relation.type,
                object: relation.subject,
                note: relation.note,
                sourceIds: relation.sourceIds,
              ),
            );
      }
    }
  }

  /// Total number of addressable articles.
  int get entityCount =>
      philosophers.length +
      concepts.length +
      works.length +
      schools.length +
      arguments.length;

  /// Looks up a philosopher.
  Philosopher? philosopher(String id) => _philosophersById[id];

  /// Looks up a concept.
  Concept? concept(String id) => _conceptsById[id];

  /// Looks up a work.
  Work? work(String id) => _worksById[id];

  /// Looks up a school.
  School? school(String id) => _schoolsById[id];

  /// Looks up a quotation.
  Quote? quote(String id) => _quotesById[id];

  /// Looks up an argument.
  Argument? argument(String id) => _argumentsById[id];

  /// Looks up a source.
  Source? source(String id) => _sourcesById[id];

  /// Resolves a reference to whichever article it points at, or `null` when the
  /// target does not exist or is not an article kind.
  KnowledgeEntity? resolve(EntityRef ref) => switch (ref.kind) {
    EntityKind.philosopher => philosopher(ref.id),
    EntityKind.concept => concept(ref.id),
    EntityKind.work => work(ref.id),
    EntityKind.school => school(ref.id),
    EntityKind.argument => null,
    EntityKind.quote => null,
    EntityKind.source => null,
  };

  /// Whether [ref] points at something that exists.
  bool exists(EntityRef ref) => switch (ref.kind) {
    EntityKind.philosopher => _philosophersById.containsKey(ref.id),
    EntityKind.concept => _conceptsById.containsKey(ref.id),
    EntityKind.work => _worksById.containsKey(ref.id),
    EntityKind.school => _schoolsById.containsKey(ref.id),
    EntityKind.quote => _quotesById.containsKey(ref.id),
    EntityKind.argument => _argumentsById.containsKey(ref.id),
    EntityKind.source => _sourcesById.containsKey(ref.id),
  };

  /// Every article, of every kind.
  Iterable<KnowledgeEntity> get allEntities sync* {
    yield* philosophers;
    yield* concepts;
    yield* works;
    yield* schools;
  }

  /// Every relation touching [ref], oriented so that [ref] is the subject.
  List<Relation> relationsFor(EntityRef ref) =>
      List.unmodifiable(_adjacency[ref] ?? const <Relation>[]);

  /// Relations touching [ref] of a particular [type].
  List<Relation> relationsOfType(EntityRef ref, RelationType type) =>
      relationsFor(ref).where((relation) => relation.type == type).toList();

  /// Quotations attributed to a philosopher, best-attested first.
  List<Quote> quotesBy(String philosopherId) =>
      quotes.where((quote) => quote.speakerId == philosopherId).toList()
        ..sort((a, b) => a.attribution.order.compareTo(b.attribution.order));

  /// Works written by a philosopher, in chronological order where known.
  List<Work> worksBy(String philosopherId) =>
      works.where((work) => work.authorId == philosopherId).toList()
        ..sort((a, b) {
          final aYear = a.composed?.start?.year;
          final bYear = b.composed?.start?.year;
          if (aYear == null && bYear == null) {
            return a.name.en.compareTo(b.name.en);
          }
          if (aYear == null) return 1;
          if (bYear == null) return -1;
          return aYear.compareTo(bYear);
        });

  /// Philosophers falling under a branch of philosophy.
  List<Philosopher> philosophersInBranch(PhilosophyBranch branch) =>
      philosophers.where((it) => it.branches.contains(branch)).toList();

  /// Philosophers belonging to a tradition.
  List<Philosopher> philosophersInTradition(Tradition tradition) =>
      philosophers.where((it) => it.traditions.contains(tradition)).toList();

  /// Every philosopher with a datable anchor, in chronological order — the
  /// backing list for timeline views.
  List<Philosopher> get philosophersChronologically {
    final datable = philosophers
        .where((it) => it.timelineAnchor != null)
        .toList();
    datable.sort(
      (a, b) => a.timelineAnchor!.year.compareTo(b.timelineAnchor!.year),
    );
    return datable;
  }

  /// Checks every cross-reference in the corpus.
  ///
  /// A reference work's credibility dies by a thousand dead links, and content
  /// is authored by hand across several files, so nothing here can be assumed.
  /// This returns every violation rather than the first, so an editor can fix a
  /// batch in one pass; `test/data/content_integrity_test.dart` asserts the
  /// result is empty for the shipped corpus.
  List<String> findIntegrityViolations() {
    final violations = <String>[];

    void checkIds(
      String context,
      String field,
      List<String> ids,
      bool Function(String) exists,
    ) {
      for (final id in ids) {
        if (!exists(id)) {
          violations.add('$context: $field references unknown "$id"');
        }
      }
    }

    bool philosopherExists(String id) => _philosophersById.containsKey(id);
    bool conceptExists(String id) => _conceptsById.containsKey(id);
    bool workExists(String id) => _worksById.containsKey(id);
    bool schoolExists(String id) => _schoolsById.containsKey(id);
    bool sourceExists(String id) => _sourcesById.containsKey(id);
    bool argumentExists(String id) => _argumentsById.containsKey(id);

    void checkCitations(String context, List<Citation> citations) {
      for (final citation in citations) {
        if (!sourceExists(citation.sourceId)) {
          violations.add(
            '$context: cites unknown source "${citation.sourceId}"',
          );
        }
      }
    }

    for (final philosopher in philosophers) {
      final context = 'philosopher:${philosopher.id}';
      checkIds(context, 'concepts', philosopher.conceptIds, conceptExists);
      checkIds(context, 'works', philosopher.workIds, workExists);
      checkIds(context, 'schools', philosopher.schoolIds, schoolExists);
      checkCitations(context, philosopher.citations);
      checkCitations(context, philosopher.article.allCitations);
    }

    for (final concept in concepts) {
      final context = 'concept:${concept.id}';
      checkIds(context, 'related', concept.relatedConceptIds, conceptExists);
      checkIds(context, 'opposes', concept.opposingConceptIds, conceptExists);
      checkIds(
        context,
        'philosophers',
        concept.philosopherIds,
        philosopherExists,
      );
      checkIds(context, 'works', concept.workIds, workExists);
      checkCitations(context, concept.citations);
      checkCitations(context, concept.article.allCitations);
    }

    for (final work in works) {
      final context = 'work:${work.id}';
      if (!philosopherExists(work.authorId)) {
        violations.add(
          '$context: author references unknown "${work.authorId}"',
        );
      }
      checkIds(context, 'concepts', work.conceptIds, conceptExists);
      checkIds(context, 'arguments', work.argumentIds, argumentExists);
      checkIds(context, 'editions', work.editionSourceIds, sourceExists);
      checkCitations(context, work.citations);
      checkCitations(context, work.article.allCitations);
    }

    for (final school in schools) {
      final context = 'school:${school.id}';
      checkIds(context, 'members', school.memberIds, philosopherExists);
      checkIds(context, 'founders', school.founderIds, philosopherExists);
      checkIds(context, 'concepts', school.conceptIds, conceptExists);
      checkIds(context, 'opposes', school.opposedSchoolIds, schoolExists);
      checkCitations(context, school.citations);
      checkCitations(context, school.article.allCitations);
    }

    for (final quote in quotes) {
      final context = 'quote:${quote.id}';
      if (!philosopherExists(quote.speakerId)) {
        violations.add(
          '$context: speaker references unknown "${quote.speakerId}"',
        );
      }
      final workId = quote.workId;
      if (workId != null && !workExists(workId)) {
        violations.add('$context: work references unknown "$workId"');
      }
      final citation = quote.citation;
      if (citation != null) checkCitations(context, <Citation>[citation]);
      if (!quote.isPublishable) {
        violations.add(
          '$context: attribution "${quote.attribution.id}" is not supported — '
          'verified quotations need a citation, others need an '
          'attributionNote',
        );
      }
      checkIds(context, 'concepts', quote.conceptIds, conceptExists);
    }

    for (final argument in arguments) {
      final context = 'argument:${argument.id}';
      checkIds(context, 'proponents', argument.proponentIds, philosopherExists);
      checkIds(context, 'opponents', argument.opponentIds, philosopherExists);
      checkIds(context, 'concepts', argument.conceptIds, conceptExists);
      final workId = argument.workId;
      if (workId != null && !workExists(workId)) {
        violations.add('$context: work references unknown "$workId"');
      }
      if (!argument.hasWellFormedObjections) {
        violations.add('$context: an objection targets a premise that is gone');
      }
      for (final objection in argument.objections) {
        final raisedBy = objection.raisedByPhilosopherId;
        if (raisedBy != null && !philosopherExists(raisedBy)) {
          violations.add(
            '$context: objection "${objection.id}" raisedBy unknown "$raisedBy"',
          );
        }
        checkCitations(context, objection.citations);
      }
      checkCitations(context, argument.citations);
    }

    for (final relation in relations) {
      if (!exists(relation.subject)) {
        violations.add('relation $relation: subject does not exist');
      }
      if (!exists(relation.object)) {
        violations.add('relation $relation: object does not exist');
      }
      for (final sourceId in relation.sourceIds) {
        if (!sourceExists(sourceId)) {
          violations.add('relation $relation: unknown source "$sourceId"');
        }
      }
    }

    return violations;
  }

  /// Throws when the corpus has any integrity violation.
  void assertIntegrity() {
    final violations = findIntegrityViolations();
    if (violations.isNotEmpty) throw ContentIntegrityException(violations);
  }
}
