import 'package:philosophyy/data/content/json_reader.dart';
import 'package:philosophyy/domain/entities/argument.dart';
import 'package:philosophyy/domain/entities/concept.dart';
import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/primer_step.dart';
import 'package:philosophyy/domain/entities/problem.dart';
import 'package:philosophyy/domain/entities/quote.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/school.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';

/// Turns authored JSON into domain objects.
///
/// The mappers are strict on purpose. Anything they cannot read is a defect in
/// content that shipped inside the app, and failing loudly at load time — where
/// a test will catch it — is far better than rendering a half-empty article to
/// a reader.
abstract final class ContentMappers {
  /// Reads `{"en": "...", "fa": "...", …}`.
  ///
  /// Any further subtag in the object is carried through as a translation
  /// rather than ignored, so content can be authored in a language ahead of the
  /// interface being able to show it. English is required: it is the authoring
  /// pivot and the fallback when nothing else is available.
  static LocalizedText localizedText(JsonReader reader) {
    final extra = reader.stringMap(except: const <String>{'en', 'fa'});
    for (final code in extra.keys) {
      // Without this, a mistyped or misplaced field inside a localized object
      // would be silently stored as a translation into a language that does not
      // exist — a loss nobody would ever see.
      if (!_languageSubtag.hasMatch(code)) {
        reader.invalid(
          '"$code" is not a language subtag; a localized string may only hold '
          'languages',
          field: code,
        );
      }
    }
    return LocalizedText(
      en: reader.requiredString('en'),
      fa: reader.string('fa'),
      translations: extra,
    );
  }

  /// A BCP-47 language subtag, optionally with a script and a region —
  /// `ar`, `zh-Hant`, `pt-BR`.
  static final RegExp _languageSubtag = RegExp(
    r'^[a-z]{2,3}(-[A-Z][a-z]{3})?(-([A-Z]{2}|\d{3}))?$',
  );

  /// Reads a required localized-text object at [field].
  static LocalizedText requiredLocalized(JsonReader reader, String field) =>
      localizedText(reader.requiredObject(field));

  /// Reads an optional localized-text object at [field].
  static LocalizedText? optionalLocalized(JsonReader reader, String field) {
    final nested = reader.object(field);
    return nested == null ? null : localizedText(nested);
  }

  /// Reads a list of localized-text objects at [field].
  static List<LocalizedText> localizedList(JsonReader reader, String field) =>
      reader.objectList(field).map(localizedText).toList();

  /// Reads `{"year": -428, "precision": "circa"}`.
  static HistoricalYear historicalYear(JsonReader reader) {
    final year = reader.requiredInt('year');
    if (year == 0) {
      reader.invalid(
        'there is no year zero: use -1 for 1 BCE and 1 for 1 CE',
        field: 'year',
      );
    }
    return HistoricalYear(
      year,
      precision:
          reader.optionalEnum(
            'precision',
            _datePrecisionFromId,
            _datePrecisionIds,
          ) ??
          DatePrecision.exact,
    );
  }

  /// Reads an optional year object at [field].
  static HistoricalYear? optionalYear(JsonReader reader, String field) {
    final nested = reader.object(field);
    return nested == null ? null : historicalYear(nested);
  }

  /// Reads `{"start": {...}, "end": {...}}`.
  static HistoricalRange? optionalRange(JsonReader reader, String field) {
    final nested = reader.object(field);
    if (nested == null) return null;
    final start = optionalYear(nested, 'start');
    final end = optionalYear(nested, 'end');
    if (start == null && end == null) {
      nested.invalid('a range needs at least one endpoint');
    }
    return HistoricalRange(start: start, end: end);
  }

  /// Reads a life span, rejecting one where death precedes birth.
  static LifeSpan lifeSpan(JsonReader reader) {
    final birth = optionalYear(reader, 'birth');
    final death = optionalYear(reader, 'death');
    if (birth != null && death != null && death.year < birth.year) {
      reader.invalid('death (${death.year}) precedes birth (${birth.year})');
    }
    return LifeSpan(
      birth: birth,
      death: death,
      floruit: optionalRange(reader, 'floruit'),
    );
  }

  /// Reads `{"source": "...", "locator": "...", "note": {...}}`.
  static Citation citation(JsonReader reader) => Citation(
    sourceId: reader.requiredString('source'),
    locator: reader.string('locator'),
    note: optionalLocalized(reader, 'note'),
  );

  /// Reads a list of citations at [field].
  static List<Citation> citations(JsonReader reader, String field) =>
      reader.objectList(field).map(citation).toList();

  /// Reads one section of an article.
  static ContentSection contentSection(JsonReader reader) => ContentSection(
    id: reader.requiredString('id'),
    heading: optionalLocalized(reader, 'heading'),
    body: requiredLocalized(reader, 'body'),
    depth:
        reader.optionalEnum('depth', ContentDepth.fromId, _contentDepthIds) ??
        ContentDepth.standard,
    claimType:
        reader.optionalEnum('claim', ClaimType.fromId, _claimTypeIds) ??
        ClaimType.fact,
    citations: citations(reader, 'citations'),
    attributedTo: reader.string('attributedTo'),
  );

  /// Reads an article, which may be absent.
  static Article article(JsonReader reader, String field) {
    final nested = reader.object(field);
    if (nested == null) return Article.empty;
    return Article(
      sections: nested.objectList('sections').map(contentSection).toList(),
    );
  }

  /// Reads one taxonomy term.
  static TaxonomyTerm taxonomyTerm(JsonReader reader) => TaxonomyTerm(
    id: reader.requiredString('id'),
    kind: reader.requiredEnum(
      'kind',
      TaxonomyKind.fromId,
      TaxonomyKind.values.map((value) => value.id),
    ),
    name: requiredLocalized(reader, 'name'),
    parentId: reader.string('parent'),
    order: reader.integer('order') ?? 0,
    note: optionalLocalized(reader, 'note'),
  );

  /// Reads a bibliographic source.
  static Source source(JsonReader reader) => Source(
    id: reader.requiredString('id'),
    kind: reader.requiredEnum('kind', SourceKind.fromId, _sourceKindIds),
    title: requiredLocalized(reader, 'title'),
    authors: reader.stringList('authors'),
    authorsFa: reader.stringList('authorsFa'),
    year: optionalYear(reader, 'year'),
    publisher: reader.string('publisher'),
    edition: reader.string('edition'),
    translator: reader.string('translator'),
    url: reader.string('url'),
    identifier: reader.string('identifier'),
    pages: reader.string('pages'),
    license: reader.string('license'),
    rightsNote: optionalLocalized(reader, 'rightsNote'),
  );

  /// Reads a philosopher.
  static Philosopher philosopher(JsonReader reader) => Philosopher(
    id: reader.requiredString('id'),
    name: requiredLocalized(reader, 'name'),
    oneLine: requiredLocalized(reader, 'oneLine'),
    nativeName: reader.string('nativeName'),
    transliteration: reader.string('transliteration'),
    alsoKnownAs: reader.stringList('alsoKnownAs'),
    life: lifeSpan(reader.requiredObject('life')),
    birthPlace: optionalLocalized(reader, 'birthPlace'),
    deathPlace: optionalLocalized(reader, 'deathPlace'),
    traditions: reader.stringList('traditions').toSet(),
    branches: reader.stringList('branches').toSet(),
    article: article(reader, 'article'),
    conceptIds: reader.stringList('concepts'),
    schoolIds: reader.stringList('schools'),
    citations: citations(reader, 'citations'),
    writings: _writings(reader),
  );

  /// Reads the `writings` field, which says what became of the person's own
  /// books.
  ///
  /// Absent means [Writings.extant], because that is the ordinary case and
  /// tagging a hundred and eighty records with the default would be noise. An
  /// unrecognised value is a content error rather than something to shrug at:
  /// silently treating a typo as the default would hide exactly the note this
  /// field exists to show.
  static Writings _writings(JsonReader reader) {
    final value = reader.string('writings');
    if (value == null) return Writings.extant;
    for (final candidate in Writings.values) {
      if (candidate.name == value) return candidate;
    }
    reader.invalid(
      'expected one of ${Writings.values.map((w) => w.name).join(', ')}',
      field: 'writings',
    );
  }

  /// Reads one step of the guided introduction.
  static PrimerStep primerStep(JsonReader reader) => PrimerStep(
    id: reader.requiredString('id'),
    title: requiredLocalized(reader, 'title'),
    body: requiredLocalized(reader, 'body'),
    question: optionalLocalized(reader, 'question'),
    reads: reader.objectList('reads').map((entry) {
      final ref = EntityRef.tryParse(entry.requiredString('ref'));
      if (ref == null) {
        entry.invalid(
          'expected a reference of the form "kind:id"',
          field: 'ref',
        );
      }
      return ref;
    }).toList(),
    citations: citations(reader, 'citations'),
  );

  /// Reads a glossary term.
  static GlossaryTerm glossaryTerm(JsonReader reader) => GlossaryTerm(
    id: reader.requiredString('id'),
    term: requiredLocalized(reader, 'term'),
    shortDefinition: requiredLocalized(reader, 'short'),
    longDefinition: optionalLocalized(reader, 'long'),
    nativeTerm: reader.string('nativeTerm'),
    transliteration: reader.string('transliteration'),
    aliases: reader.stringList('aliases'),
    conceptId: reader.string('concept'),
    citations: citations(reader, 'citations'),
  );

  /// Reads a concept.
  static Concept concept(JsonReader reader) => Concept(
    id: reader.requiredString('id'),
    name: requiredLocalized(reader, 'name'),
    oneLine: requiredLocalized(reader, 'oneLine'),
    shortDefinition: requiredLocalized(reader, 'definition'),
    nativeTerm: reader.string('nativeTerm'),
    transliteration: reader.string('transliteration'),
    alsoKnownAs: reader.stringList('alsoKnownAs'),
    traditions: reader.stringList('traditions').toSet(),
    branches: reader.stringList('branches').toSet(),
    article: article(reader, 'article'),
    examples: localizedList(reader, 'examples'),
    counterexamples: localizedList(reader, 'counterexamples'),
    relatedConceptIds: reader.stringList('related'),
    opposingConceptIds: reader.stringList('opposes'),
    philosopherIds: reader.stringList('philosophers'),
    workIds: reader.stringList('works'),
    citations: citations(reader, 'citations'),
  );

  /// Reads one division of a work, recursing into its children.
  static WorkDivision workDivision(JsonReader reader) => WorkDivision(
    id: reader.requiredString('id'),
    title: requiredLocalized(reader, 'title'),
    summary: optionalLocalized(reader, 'summary'),
    locator: reader.string('locator'),
    children: reader.objectList('children').map(workDivision).toList(),
  );

  /// Reads a work.
  static Work work(JsonReader reader) => Work(
    id: reader.requiredString('id'),
    name: requiredLocalized(reader, 'title'),
    oneLine: requiredLocalized(reader, 'oneLine'),
    authorId: reader.requiredString('author'),
    originalTitle: reader.string('originalTitle'),
    transliteration: reader.string('transliteration'),
    alsoKnownAs: reader.stringList('alsoKnownAs'),
    composed: optionalRange(reader, 'composed'),
    traditions: reader.stringList('traditions').toSet(),
    branches: reader.stringList('branches').toSet(),
    article: article(reader, 'article'),
    structure: reader.objectList('structure').map(workDivision).toList(),
    conceptIds: reader.stringList('concepts'),
    argumentIds: reader.stringList('arguments'),
    editionSourceIds: reader.stringList('editions'),
    citations: citations(reader, 'citations'),
  );

  /// Reads a quotation, enforcing the editorial rules on attribution.
  static Quote quote(JsonReader reader) {
    final attribution = reader.requiredEnum(
      'attribution',
      AttributionStatus.fromId,
      _attributionIds,
    );
    final citationObject = reader.object('citation');
    final note = optionalLocalized(reader, 'attributionNote');

    // These two rules are the whole point of tracking attribution, so they are
    // enforced where content enters the system rather than trusted to review.
    if (attribution == AttributionStatus.verified && citationObject == null) {
      reader.invalid(
        'a quotation marked "verified" must carry a citation locating it in a '
        'source; use "probable" if the passage has not been located',
      );
    }
    if (attribution != AttributionStatus.verified && note == null) {
      reader.invalid(
        'a quotation not marked "verified" must carry an attributionNote '
        'explaining the doubt, which the interface shows to the reader',
      );
    }

    return Quote(
      id: reader.requiredString('id'),
      text: requiredLocalized(reader, 'text'),
      originalText: reader.string('originalText'),
      transliteration: reader.string('transliteration'),
      speakerId: reader.requiredString('speaker'),
      workId: reader.string('work'),
      citation: citationObject == null ? null : citation(citationObject),
      attribution: attribution,
      context: optionalLocalized(reader, 'context'),
      attributionNote: note,
      actualSource: optionalLocalized(reader, 'actualSource'),
      conceptIds: reader.stringList('concepts'),
    );
  }

  /// Reads a school.
  static School school(JsonReader reader) => School(
    id: reader.requiredString('id'),
    name: requiredLocalized(reader, 'name'),
    oneLine: requiredLocalized(reader, 'oneLine'),
    nativeName: reader.string('nativeName'),
    transliteration: reader.string('transliteration'),
    alsoKnownAs: reader.stringList('alsoKnownAs'),
    period: optionalRange(reader, 'period'),
    traditions: reader.stringList('traditions').toSet(),
    branches: reader.stringList('branches').toSet(),
    article: article(reader, 'article'),
    centralClaims: localizedList(reader, 'centralClaims'),
    memberIds: reader.stringList('members'),
    founderIds: reader.stringList('founders'),
    conceptIds: reader.stringList('concepts'),
    opposedSchoolIds: reader.stringList('opposes'),
    citations: citations(reader, 'citations'),
  );

  /// Reads one step of an argument.
  static ArgumentStatement argumentStatement(JsonReader reader) {
    final citationObject = reader.object('citation');
    return ArgumentStatement(
      id: reader.requiredString('id'),
      text: requiredLocalized(reader, 'text'),
      gloss: optionalLocalized(reader, 'gloss'),
      citation: citationObject == null ? null : citation(citationObject),
    );
  }

  /// Reads an objection.
  static Objection objection(JsonReader reader) => Objection(
    id: reader.requiredString('id'),
    text: requiredLocalized(reader, 'text'),
    targetStatementIds: reader.stringList('targets'),
    raisedByPhilosopherId: reader.string('raisedBy'),
    replies: localizedList(reader, 'replies'),
    citations: citations(reader, 'citations'),
  );

  /// Reads an argument, rejecting one whose objections point at premises that
  /// do not exist.
  static Argument argument(JsonReader reader) {
    final parsed = Argument(
      id: reader.requiredString('id'),
      name: requiredLocalized(reader, 'name'),
      oneLine: requiredLocalized(reader, 'oneLine'),
      premises: reader.objectList('premises').map(argumentStatement).toList(),
      conclusion: argumentStatement(reader.requiredObject('conclusion')),
      assumptions: localizedList(reader, 'assumptions'),
      objections: reader.objectList('objections').map(objection).toList(),
      proponentIds: reader.stringList('proponents'),
      opponentIds: reader.stringList('opponents'),
      workIds: reader.stringList('works'),
      conceptIds: reader.stringList('concepts'),
      traditions: reader.stringList('traditions').toSet(),
      branches: reader.stringList('branches').toSet(),
      citations: citations(reader, 'citations'),
      article: article(reader, 'article'),
      attribution:
          reader.optionalEnum(
            'attribution',
            RelationConfidence.fromId,
            RelationConfidence.values.map((value) => value.id),
          ) ??
          RelationConfidence.accepted,
      attributionNote: optionalLocalized(reader, 'attributionNote'),
    );

    if (parsed.premises.isEmpty) {
      reader.invalid('an argument must have at least one premise');
    }
    if (!parsed.hasWellFormedObjections) {
      reader.invalid(
        'an objection targets a premise that does not exist in this argument',
      );
    }
    // A qualified attribution the reader is not told the reason for is a badge
    // rather than information.
    if (!parsed.hasSettledAttribution && parsed.attributionNote == null) {
      reader.invalid(
        'an attribution marked "${parsed.attribution.id}" must say why in '
        '"attributionNote"',
      );
    }
    return parsed;
  }

  /// Reads one stance taken on a problem.
  static Position position(JsonReader reader) {
    final parsed = Position(
      id: reader.requiredString('id'),
      name: requiredLocalized(reader, 'name'),
      summary: requiredLocalized(reader, 'summary'),
      philosopherIds: reader.stringList('philosophers'),
      argumentIds: reader.stringList('arguments'),
      schoolIds: reader.stringList('schools'),
      citations: citations(reader, 'citations'),
      attribution:
          reader.optionalEnum(
            'attribution',
            RelationConfidence.fromId,
            RelationConfidence.values.map((value) => value.id),
          ) ??
          RelationConfidence.accepted,
      attributionNote: optionalLocalized(reader, 'attributionNote'),
    );
    if (!parsed.hasSettledAttribution && parsed.attributionNote == null) {
      reader.invalid(
        'a position marked "${parsed.attribution.id}" must say why in '
        '"attributionNote"',
      );
    }
    return parsed;
  }

  /// Reads one philosophical problem.
  static Problem problem(JsonReader reader) {
    final parsed = Problem(
      id: reader.requiredString('id'),
      name: requiredLocalized(reader, 'name'),
      oneLine: requiredLocalized(reader, 'oneLine'),
      question: requiredLocalized(reader, 'question'),
      positions: reader.objectList('positions').map(position).toList(),
      argumentIds: reader.stringList('arguments'),
      conceptIds: reader.stringList('concepts'),
      workIds: reader.stringList('works'),
      traditions: reader.stringList('traditions').toSet(),
      branches: reader.stringList('branches').toSet(),
      article: article(reader, 'article'),
      citations: citations(reader, 'citations'),
    );

    // A problem with one position is not a problem, it is a claim. The whole
    // point of the kind is to hold a disagreement, and an entry that records
    // only the side the editor finds convincing has taken that side silently.
    if (parsed.positions.length < 2) {
      reader.invalid(
        'a problem must record at least two positions; '
        'found ${parsed.positions.length}',
      );
    }

    final seen = <String>{};
    for (final stance in parsed.positions) {
      if (!seen.add(stance.id)) {
        reader.invalid('two positions share the id "${stance.id}"');
      }
    }
    return parsed;
  }

  /// Reads one edge of the knowledge graph.
  static Relation relation(JsonReader reader) {
    final subject = EntityRef.tryParse(reader.requiredString('subject'));
    if (subject == null) {
      reader.invalid(
        'expected a reference of the form "kind:id", e.g. "philosopher:plato"',
        field: 'subject',
      );
    }
    final object = EntityRef.tryParse(reader.requiredString('object'));
    if (object == null) {
      reader.invalid(
        'expected a reference of the form "kind:id", e.g. "concept:justice"',
        field: 'object',
      );
    }
    if (subject == object) {
      reader.invalid('an entity cannot be related to itself');
    }
    return Relation(
      subject: subject,
      type: reader.requiredEnum('type', RelationType.fromId, _relationTypeIds),
      object: object,
      confidence:
          reader.optionalEnum(
            'confidence',
            RelationConfidence.fromId,
            _relationConfidenceIds,
          ) ??
          RelationConfidence.accepted,
      note: optionalLocalized(reader, 'note'),
      sourceIds: reader.stringList('sources'),
    );
  }

  // -----------------------------------------------------------------------
  // Enumerated-value tables, used to produce helpful parse errors.
  // -----------------------------------------------------------------------

  static DatePrecision? _datePrecisionFromId(String id) => switch (id) {
    'exact' => DatePrecision.exact,
    'circa' => DatePrecision.circa,
    'decade' => DatePrecision.decade,
    'century' => DatePrecision.century,
    _ => null,
  };

  static const List<String> _datePrecisionIds = <String>[
    'exact',
    'circa',
    'decade',
    'century',
  ];

  static Iterable<String> get _contentDepthIds =>
      ContentDepth.values.map((value) => value.id);

  static Iterable<String> get _claimTypeIds =>
      ClaimType.values.map((value) => value.id);

  static Iterable<String> get _sourceKindIds =>
      SourceKind.values.map((value) => value.id);

  static Iterable<String> get _attributionIds =>
      AttributionStatus.values.map((value) => value.id);

  static Iterable<String> get _relationTypeIds =>
      RelationType.values.map((value) => value.id);

  static Iterable<String> get _relationConfidenceIds =>
      RelationConfidence.values.map((value) => value.id);
}
