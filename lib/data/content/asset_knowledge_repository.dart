import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:philosophyy/core/errors/content_exception.dart';
import 'package:philosophyy/data/content/content_mappers.dart';
import 'package:philosophyy/data/content/json_reader.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/argument.dart';
import 'package:philosophyy/domain/entities/concept.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/school.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/repositories/knowledge_repository.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';

/// Loads the corpus from the JSON bundled with the app.
///
/// Content ships inside the binary, which makes the product fully usable
/// offline from first launch — no empty state waiting on a network call, and
/// no reader stranded by a bad connection. Editorially it also means the
/// corpus is versioned with the code that renders it, so a content change and
/// the code change it needs travel together.
class AssetKnowledgeRepository implements KnowledgeRepository {
  const AssetKnowledgeRepository({this.bundle});

  /// Directory holding the content files.
  static const String contentPath = 'assets/content';

  /// The content files, in load order.
  static const String philosophersFile = '$contentPath/philosophers.json';

  /// Concept records.
  static const String conceptsFile = '$contentPath/concepts.json';

  /// Work records.
  static const String worksFile = '$contentPath/works.json';

  /// School records.
  static const String schoolsFile = '$contentPath/schools.json';

  /// Quotation records.
  static const String quotesFile = '$contentPath/quotes.json';

  /// Argument records.
  static const String argumentsFile = '$contentPath/arguments.json';

  /// Bibliographic sources.
  static const String sourcesFile = '$contentPath/sources.json';

  /// Knowledge-graph edges.
  static const String relationsFile = '$contentPath/relations.json';

  /// The vocabulary of traditions, branches and eras the content is classified
  /// by. Content rather than code, so a tradition can be added without a
  /// release — see ADR-017.
  static const String taxonomyFile = '$contentPath/taxonomy.json';

  /// Overrides the bundle assets are read from. Tests supply their own.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  @override
  Future<KnowledgeBase> load() async {
    final base = KnowledgeBase(
      taxonomy: Taxonomy(
        await _read(
          taxonomyFile,
          'terms',
          ContentMappers.taxonomyTerm,
          identify: (term) => term.id,
        ),
      ),
      philosophers: await _read(
        philosophersFile,
        'philosophers',
        ContentMappers.philosopher,
        identify: (philosopher) => philosopher.id,
      ),
      concepts: await _read(
        conceptsFile,
        'concepts',
        ContentMappers.concept,
        identify: (concept) => concept.id,
      ),
      works: await _read(
        worksFile,
        'works',
        ContentMappers.work,
        identify: (work) => work.id,
      ),
      schools: await _read(
        schoolsFile,
        'schools',
        ContentMappers.school,
        identify: (school) => school.id,
      ),
      quotes: await _read(
        quotesFile,
        'quotes',
        ContentMappers.quote,
        identify: (quote) => quote.id,
      ),
      arguments: await _read(
        argumentsFile,
        'arguments',
        ContentMappers.argument,
        identify: (argument) => argument.id,
      ),
      sources: await _read(
        sourcesFile,
        'sources',
        ContentMappers.source,
        identify: (source) => source.id,
      ),
      relations: await _read(
        relationsFile,
        'relations',
        ContentMappers.relation,
      ),
    );

    // Cross-references are checked before the corpus is handed out, so a broken
    // link fails at startup — where tests and CI see it — rather than becoming
    // a blank screen for a reader who tapped something.
    base.assertIntegrity();
    return base;
  }

  /// Reads one content file and maps the array named [collection].
  ///
  /// [identify] extracts the record's identifier so duplicates can be rejected.
  /// It is optional because not every record is addressable — a relation is an
  /// edge between two entities and has no identity of its own.
  Future<List<T>> _read<T>(
    String file,
    String collection,
    T Function(JsonReader) map, {
    String Function(T)? identify,
  }) async {
    final String raw;
    try {
      raw = await _assets.loadString(file);
    } on Object catch (error) {
      throw ContentException(
        message: 'content file could not be loaded from the bundle',
        path: r'$',
        file: file,
        cause: error,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw ContentException(
        message: 'file is not valid JSON',
        path: r'$',
        file: file,
        cause: error,
      );
    }

    final root = JsonReader.root(decoded, file: file);
    final items = root.objectList(collection);
    final mapped = <T>[];
    final seenIds = <String>{};

    for (final item in items) {
      final entity = map(item);
      if (identify != null && !seenIds.add(identify(entity))) {
        item.invalid(
          'duplicate id "${identify(entity)}" — identifiers must be unique '
          'within a file because they are used in links, deep links and saved '
          'reading positions',
          field: 'id',
        );
      }
      mapped.add(entity);
    }

    return mapped;
  }
}

/// Builds a corpus from in-memory JSON strings.
///
/// Used by tests, which need to exercise loading and integrity checking against
/// deliberately broken content without touching the shipped files.
class InMemoryKnowledgeRepository implements KnowledgeRepository {
  const InMemoryKnowledgeRepository({
    this.philosophers = const <Philosopher>[],
    this.concepts = const <Concept>[],
    this.works = const <Work>[],
    this.schools = const <School>[],
    this.quotes = const <Quote>[],
    this.arguments = const <Argument>[],
    this.sources = const <Source>[],
    this.relations = const <Relation>[],
    this.taxonomy,
    this.validate = true,
  });

  /// Philosophers to serve.
  final List<Philosopher> philosophers;

  /// Concepts to serve.
  final List<Concept> concepts;

  /// Works to serve.
  final List<Work> works;

  /// Schools to serve.
  final List<School> schools;

  /// Quotations to serve.
  final List<Quote> quotes;

  /// Arguments to serve.
  final List<Argument> arguments;

  /// Sources to serve.
  final List<Source> sources;

  /// Relations to serve.
  final List<Relation> relations;

  /// The vocabulary to classify against. Tests that tag entities with a
  /// tradition must supply the term, exactly as content must define it.
  final Taxonomy? taxonomy;

  /// Whether to run the integrity check, which a test exercising broken
  /// content will want to switch off.
  final bool validate;

  @override
  Future<KnowledgeBase> load() async {
    final base = KnowledgeBase(
      philosophers: philosophers,
      concepts: concepts,
      works: works,
      schools: schools,
      quotes: quotes,
      arguments: arguments,
      sources: sources,
      relations: relations,
      taxonomy: taxonomy,
    );
    if (validate) base.assertIntegrity();
    return base;
  }
}
