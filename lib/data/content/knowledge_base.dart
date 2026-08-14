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
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';

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
    Taxonomy? taxonomy,
  }) : taxonomy = taxonomy ?? Taxonomy.empty,
       philosophers = List.unmodifiable(philosophers),
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

  /// The vocabulary of traditions, branches and eras this corpus is classified
  /// by.
  ///
  /// It travels with the corpus rather than being a global, because a term's
  /// meaning is only guaranteed against the content that was authored alongside
  /// it — and because a test that builds a small corpus should be able to build
  /// a small vocabulary with it.
  final Taxonomy taxonomy;

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
      // Both ends get the edge, oriented so the entity being read is always the
      // subject. [Relation.inverted] handles the symmetric case — it does not
      // flip the reading flag for a type that reads the same from either end —
      // so there is one path here rather than two. There used to be two, and
      // the second one dropped the confidence.
      _adjacency
          .putIfAbsent(relation.object, () => <Relation>[])
          .add(relation.inverted);
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

  /// Philosophers falling under a branch of philosophy, by taxonomy id.
  ///
  /// A philosopher tagged with a narrower branch counts under the wider one:
  /// someone classified under `metaethics` is returned for `ethics`. Without
  /// that, a reader browsing "Ethics" would silently miss the entries filed
  /// most precisely, which is exactly backwards.
  List<Philosopher> philosophersInBranch(String branchId) => philosophers
      .where(
        (it) =>
            it.branches.contains(branchId) ||
            it.branches.any((id) => taxonomy.isUnder(id, branchId)),
      )
      .toList();

  /// Philosophers belonging to a tradition, by taxonomy id. Narrower
  /// traditions count under wider ones, as for [philosophersInBranch].
  List<Philosopher> philosophersInTradition(String traditionId) => philosophers
      .where(
        (it) =>
            it.traditions.contains(traditionId) ||
            it.traditions.any((id) => taxonomy.isUnder(id, traditionId)),
      )
      .toList();

  /// Every taxonomy id actually used by the corpus, of the given kind.
  ///
  /// Browsing surfaces are built from this rather than from the whole
  /// vocabulary, so the reader is never offered a filter that leads nowhere.
  Set<String> usedTaxonomyIds(TaxonomyKind kind) {
    final used = <String>{};
    for (final entity in allEntities) {
      final ids = kind == TaxonomyKind.tradition
          ? entity.traditions
          : entity.branches;
      for (final id in ids) {
        final term = taxonomy[id];
        if (term != null && term.kind == kind) used.add(id);
      }
    }
    return used;
  }

  /// Works in the order they were written, undated ones last.
  ///
  /// Chronological rather than alphabetical for the same reason philosophers
  /// are: the order in which the arguments were made is the useful order, and
  /// an alphabetical list files the *Analects* next to the *Apology* for no
  /// reason at all. Undated works sort to the end by title rather than being
  /// dropped, because a work whose date is genuinely unknown is still a work.
  List<Work> get worksChronologically {
    final ordered = <Work>[...works];
    ordered.sort((a, b) {
      final aYear = a.composed?.start?.year;
      final bYear = b.composed?.start?.year;
      if (aYear == null && bYear == null) return a.name.en.compareTo(b.name.en);
      if (aYear == null) return 1;
      if (bYear == null) return -1;
      return aYear.compareTo(bYear);
    });
    return ordered;
  }

  /// The traditions an entity belongs to, falling back to its author's.
  ///
  /// A work is written inside a tradition whether or not an editor remembered
  /// to tag it, and a reader filtering to "Islamic" expects the *Ishārāt*
  /// either way. Inheriting is the honest default: it states no more than that
  /// a work belongs where its author did, and an explicit tag always wins —
  /// which is what lets a work that broke with its author's tradition say so.
  Set<String> traditionsOf(KnowledgeEntity entity) {
    if (entity.traditions.isNotEmpty) return entity.traditions;
    if (entity is Work) {
      return philosopher(entity.authorId)?.traditions ?? const <String>{};
    }
    return const <String>{};
  }

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

    // Traditions and branches used to be Dart enums, so a typo was a compile
    // error. Opening the vocabulary to content moved that guarantee here: an id
    // that resolves to nothing, or to a term of the wrong kind, is now caught
    // at load time instead of by the analyser.
    void checkTaxonomy(
      String context,
      String field,
      Iterable<String> ids,
      TaxonomyKind expected,
    ) {
      for (final id in ids) {
        final term = taxonomy[id];
        if (term == null) {
          violations.add(
            '$context: $field references unknown ${expected.id} "$id" — add it '
            'to assets/content/taxonomy.json',
          );
        } else if (term.kind != expected) {
          violations.add(
            '$context: $field references "$id", which is a ${term.kind.id}, '
            'not a ${expected.id}',
          );
        }
      }
    }

    void checkEntityTaxonomy(String context, KnowledgeEntity entity) {
      checkTaxonomy(
        context,
        'traditions',
        entity.traditions,
        TaxonomyKind.tradition,
      );
      checkTaxonomy(context, 'branches', entity.branches, TaxonomyKind.branch);
    }

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
      checkEntityTaxonomy(context, philosopher);
      checkIds(context, 'concepts', philosopher.conceptIds, conceptExists);
      checkIds(context, 'works', philosopher.workIds, workExists);
      checkIds(context, 'schools', philosopher.schoolIds, schoolExists);
      checkCitations(context, philosopher.citations);
      checkCitations(context, philosopher.article.allCitations);
    }

    for (final concept in concepts) {
      final context = 'concept:${concept.id}';
      checkEntityTaxonomy(context, concept);
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
      checkEntityTaxonomy(context, work);
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
      checkEntityTaxonomy(context, school);
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
      checkTaxonomy(
        context,
        'branches',
        argument.branches,
        TaxonomyKind.branch,
      );
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
      if (!relation.isSupported) {
        violations.add(
          'relation $relation: marked "${relation.confidence.id}" but shows '
          'nothing for it — a documented connection needs a source, and a '
          'probable, contested or speculative one needs a source or a note '
          'saying who argues it',
        );
      }
    }

    for (final termId in taxonomy.orphans) {
      violations.add(
        'taxonomy:$termId: names a parent that does not exist '
        '("${taxonomy[termId]?.parentId}")',
      );
    }

    // The old enums forced a Persian name for every tradition and branch,
    // because the label switch would not compile without one. That constraint
    // is the point of a bilingual reference work, so opening the vocabulary
    // must not quietly drop it.
    for (final term in taxonomy.all) {
      if (!term.name.isTranslated) {
        violations.add(
          'taxonomy:${term.id}: has no Persian name — every term a reader can '
          'see must be named in both languages',
        );
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
