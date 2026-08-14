import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// Holds the knowledge graph to the claims it makes.
///
/// A graph draws every edge the same way, which makes every edge look like the
/// same kind of claim. "Aristotle studied under Plato" is recorded in antiquity;
/// "Heraclitus influenced Hegel" is a reading. Presenting the second the way it
/// presents the first is how a reference work manufactures a consensus that does
/// not exist, so the confidence a relation carries has to mean something the
/// content is actually held to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const plato = EntityRef(EntityKind.philosopher, 'plato');
  const aristotle = EntityRef(EntityKind.philosopher, 'aristotle');

  group('Reading an edge from both ends', () {
    test('inversion carries the confidence with it', () {
      // A relation read from the other end is the same claim about the world,
      // so it cannot quietly become better established on the way.
      const relation = Relation(
        subject: plato,
        type: RelationType.taught,
        object: aristotle,
        confidence: RelationConfidence.probable,
        note: LocalizedText(en: 'why', fa: 'چرا'),
      );
      final inverted = relation.inverted;
      expect(inverted.confidence, RelationConfidence.probable);
      expect(inverted.subject, aristotle);
      expect(inverted.object, plato);
      expect(inverted.isInverseReading, isTrue);
      expect(inverted.inverted.isInverseReading, isFalse);
    });

    test('every type has a distinct label in each direction', () {
      // "Aristotle criticised Plato" must appear on Plato's page as
      // "criticised by", not as the same sentence with the names swapped.
      for (final type in RelationType.values) {
        if (type.isSymmetric) continue;
        expect(
          type.inverseId,
          isNot(type.id),
          reason:
              '${type.id} reads identically in both directions but is not '
              'marked symmetric',
        );
        for (final language in AppLanguage.values) {
          expect(
            TaxonomyLabels.relationForward(type).resolve(language),
            isNot(TaxonomyLabels.relationInverse(type).resolve(language)),
            reason: '${type.id} has the same ${language.name} label both ways',
          );
        }
      }
    });

    test('a symmetric type reads the same in both directions', () {
      for (final type in RelationType.values.where((t) => t.isSymmetric)) {
        expect(type.inverseId, type.id, reason: type.id);
      }
    });
  });

  group('Nothing is lost when an edge is read from the other end', () {
    test('every type and confidence survives inversion intact', () {
      // The graph used to build the symmetric case by hand instead of using
      // `inverted`, and that copy omitted the confidence — so an edge marked
      // `probable` on one page appeared unmarked on the other. Asserting the
      // whole cross-product rather than one example, because the bug lived in a
      // branch that only some types took.
      const note = LocalizedText(en: 'why', fa: 'چرا');
      for (final type in RelationType.values) {
        for (final confidence in RelationConfidence.values) {
          final relation = Relation(
            subject: plato,
            type: type,
            object: aristotle,
            confidence: confidence,
            note: note,
            sourceIds: const <String>['sep'],
          );
          final back = relation.inverted;
          expect(
            back.confidence,
            confidence,
            reason: '${type.id}/${confidence.id} lost its confidence',
          );
          expect(back.note, note, reason: '${type.id} lost its note');
          expect(
            back.sourceIds,
            relation.sourceIds,
            reason: '${type.id} lost its sources',
          );
          expect(back.isSupported, relation.isSupported);
        }
      }
    });

    test('a symmetric edge keeps the forward reading, an asymmetric one flips', () {
      // "Contradicts" reads the same from either end, so flagging the far side
      // as an inverse reading would label it with a phrase meant for the other
      // direction.
      for (final type in RelationType.values) {
        final relation = Relation(
          subject: plato,
          type: type,
          object: aristotle,
        );
        expect(
          relation.inverted.isInverseReading,
          !type.isSymmetric,
          reason: type.id,
        );
        expect(
          relation.inverted.labelId,
          type.isSymmetric ? type.id : type.inverseId,
          reason: type.id,
        );
      }
    });

    test('inverting twice returns the original reading', () {
      for (final type in RelationType.values) {
        const base = Relation(
          subject: plato,
          type: RelationType.influenced,
          object: aristotle,
        );
        final round = Relation(
          subject: base.subject,
          type: type,
          object: base.object,
        ).inverted.inverted;
        expect(round.subject, plato, reason: type.id);
        expect(round.isInverseReading, isFalse, reason: type.id);
      }
    });
  });

  group('The shipped graph, read from both ends', () {
    late KnowledgeBase corpus;

    setUpAll(() async {
      corpus = await const AssetKnowledgeRepository().load();
    });

    test('an edge carries the same confidence on both pages', () {
      // The failure this catches is invisible from one side: the Beauvoir–Du
      // Bois comparison was marked `probable` on her page and unmarked on his,
      // so a reader arriving from Du Bois saw a scholarly reading presented as
      // settled fact.
      final mismatches = <String>[];
      for (final authored in corpus.relations) {
        RelationConfidence? seenFrom(EntityRef ref, EntityRef other) {
          for (final edge in corpus.relationsFor(ref)) {
            if (edge.type == authored.type && edge.object == other) {
              return edge.confidence;
            }
          }
          return null;
        }

        final fromSubject = seenFrom(authored.subject, authored.object);
        final fromObject = seenFrom(authored.object, authored.subject);
        if (fromSubject != authored.confidence ||
            fromObject != authored.confidence) {
          mismatches.add(
            '$authored authored=${authored.confidence.id} '
            'subject-side=${fromSubject?.id} object-side=${fromObject?.id}',
          );
        }
      }
      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    });

    test('every entity sees each of its edges exactly once', () {
      // A symmetric edge added twice would show the reader the same connection
      // duplicated on the page.
      for (final ref in <EntityRef>{
        for (final relation in corpus.relations) ...<EntityRef>[
          relation.subject,
          relation.object,
        ],
      }) {
        final seen = <String>[];
        for (final edge in corpus.relationsFor(ref)) {
          seen.add('${edge.type.id}->${edge.object}');
        }
        expect(
          seen.length,
          seen.toSet().length,
          reason: '$ref sees a duplicated edge: $seen',
        );
      }
    });
  });

  group('Bilingual labels', () {
    test('every relation type is named in both languages', () {
      // The guarantee that adding a type cannot ship an untranslated label.
      for (final type in RelationType.values) {
        expect(
          TaxonomyLabels.relationForward(type).isTranslated,
          isTrue,
          reason: '${type.id} has no Persian forward label',
        );
        expect(
          TaxonomyLabels.relationInverse(type).isTranslated,
          isTrue,
          reason: '${type.id} has no Persian inverse label',
        );
      }
    });

    test('every confidence level is named and explained in both languages', () {
      for (final confidence in RelationConfidence.values) {
        expect(
          TaxonomyLabels.relationConfidence(confidence).isTranslated,
          isTrue,
          reason: '${confidence.id} has no Persian label',
        );
        expect(
          TaxonomyLabels.relationConfidenceExplanation(confidence).isTranslated,
          isTrue,
          reason: '${confidence.id} has no Persian explanation',
        );
      }
    });
  });

  group('What a confidence level obliges the content to show', () {
    Relation edge(
      RelationConfidence confidence, {
      List<String> sources = const <String>[],
      LocalizedText? note,
    }) => Relation(
      subject: plato,
      type: RelationType.influenced,
      object: aristotle,
      confidence: confidence,
      sourceIds: sources,
      note: note,
    );

    test('a documented edge must name the text', () {
      // "A text says so" is a claim a reader should be able to follow up.
      expect(edge(RelationConfidence.documented).isSupported, isFalse);
      expect(
        edge(
          RelationConfidence.documented,
          sources: const <String>['sep'],
        ).isSupported,
        isTrue,
      );
      // A note is not enough here: the claim is specifically about a text.
      expect(
        edge(
          RelationConfidence.documented,
          note: const LocalizedText(en: 'a note', fa: 'یادداشت'),
        ).isSupported,
        isFalse,
      );
    });

    test('an accepted edge needs nothing further', () {
      // It claims only that the connection is standard, which is what the
      // absence of a marking already tells the reader.
      expect(edge(RelationConfidence.accepted).isSupported, isTrue);
    });

    test('a contested or speculative edge must say who argues it', () {
      for (final confidence in const <RelationConfidence>[
        RelationConfidence.probable,
        RelationConfidence.contested,
        RelationConfidence.speculative,
      ]) {
        expect(
          edge(confidence).isSupported,
          isFalse,
          reason: '${confidence.id} passed with nothing behind it',
        );
        expect(
          edge(
            confidence,
            note: const LocalizedText(en: 'who argues it', fa: 'که می‌گوید'),
          ).isSupported,
          isTrue,
        );
        expect(
          edge(confidence, sources: const <String>['sep']).isSupported,
          isTrue,
        );
      }
    });

    test('only documented and accepted may be shown unmarked', () {
      expect(RelationConfidence.documented.isEstablished, isTrue);
      expect(RelationConfidence.accepted.isEstablished, isTrue);
      for (final confidence in const <RelationConfidence>[
        RelationConfidence.probable,
        RelationConfidence.contested,
        RelationConfidence.speculative,
      ]) {
        expect(confidence.requiresMarking, isTrue, reason: confidence.id);
      }
    });

    test('an unsupported edge is an integrity violation', () {
      // The rule has to bite on real content, not only on the value object.
      final base = KnowledgeBase(
        philosophers: const [],
        concepts: const [],
        works: const [],
        schools: const [],
        quotes: const [],
        arguments: const [],
        sources: const [],
        relations: <Relation>[edge(RelationConfidence.contested)],
      );
      expect(
        base.findIntegrityViolations(),
        contains(contains('marked "contested"')),
      );
    });
  });

  group('The shipped corpus', () {
    late KnowledgeBase corpus;

    setUpAll(() async {
      corpus = await const AssetKnowledgeRepository().load();
    });

    test('every relation shows what its confidence claims', () {
      final unsupported = corpus.relations
          .where((relation) => !relation.isSupported)
          .map((relation) => '$relation (${relation.confidence.id})')
          .toList();
      expect(unsupported, isEmpty);
    });

    test('does not mark everything as equally established', () {
      // The point of the confidence field is lost if content sets one value
      // everywhere; that is the uniform tone of authority it exists to break.
      final used = corpus.relations
          .map((relation) => relation.confidence)
          .toSet();
      expect(
        used.length,
        greaterThan(1),
        reason: 'every relation in the corpus is marked ${used.first.id}',
      );
    });

    test('an interpretive connection is not presented as a reported one', () {
      // Beauvoir and Du Bois were not working from each other; the parallel is
      // a comparison scholars draw. If that edge ever becomes "documented",
      // something has gone wrong editorially.
      final comparative = corpus.relations.where(
        (relation) =>
            relation.subject.id == 'beauvoir' &&
            relation.object.id == 'du-bois',
      );
      expect(comparative, isNotEmpty);
      for (final relation in comparative) {
        expect(relation.confidence.requiresMarking, isTrue);
        expect(relation.note, isNotNull);
      }
    });
  });
}
