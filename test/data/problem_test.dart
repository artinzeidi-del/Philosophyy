import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/errors/content_exception.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/content_mappers.dart';
import 'package:philosophyy/data/content/json_reader.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// What a philosophical problem must be, and what it must not.
///
/// The kind exists to hold a disagreement. Every rule below follows from that:
/// an entry with one position has taken a side while appearing to survey the
/// field, a position nobody holds is an editor's invention, and a problem whose
/// positions rest on no arguments is a list of opinions rather than the join
/// the knowledge graph was missing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  group('Every problem in the corpus', () {
    test('records at least two positions', () {
      for (final problem in corpus.problems) {
        expect(
          problem.positions.length,
          greaterThanOrEqualTo(2),
          reason:
              '${problem.id} records ${problem.positions.length} position(s); '
              'a question with one answer is a claim, not a problem',
        );
      }
    });

    test('names someone for every position', () {
      final unheld = <String>[
        for (final problem in corpus.problems)
          for (final stance in problem.positions)
            if (stance.philosopherIds.isEmpty) '${problem.id}/${stance.id}',
      ];
      expect(
        unheld,
        isEmpty,
        reason:
            'a position nobody is recorded as holding is the editor\'s, and '
            'presenting it as a side of a historical dispute is an invention',
      );
    });

    test('rests on arguments the corpus actually contains', () {
      // The point of the kind is to join problems to arguments. A problem
      // whose positions cite no argument is a list of opinions.
      for (final problem in corpus.problems) {
        expect(
          problem.allArgumentIds,
          isNotEmpty,
          reason: '${problem.id} reaches no argument',
        );
        for (final id in problem.allArgumentIds) {
          expect(
            corpus.argument(id),
            isNotNull,
            reason: '${problem.id} points at missing argument "$id"',
          );
        }
      }
    });

    test('does not put one philosopher on two sides of itself', () {
      final doubled = <String>[];
      for (final problem in corpus.problems) {
        final seen = <String, String>{};
        for (final stance in problem.positions) {
          for (final id in stance.philosopherIds) {
            final earlier = seen[id];
            if (earlier != null) {
              doubled.add('${problem.id}: $id is in $earlier and ${stance.id}');
            }
            seen[id] = stance.id;
          }
        }
      }
      expect(doubled, isEmpty, reason: doubled.join('\n'));
    });

    test('is findable and openable', () {
      final index = SearchIndex.build(corpus);
      for (final problem in corpus.problems) {
        final hits = index
            .search(problem.name.en)
            .map((hit) => hit.entity.ref)
            .toSet();
        expect(
          hits,
          contains(problem.ref),
          reason: '${problem.id} cannot be searched for by its own name',
        );
        expect(corpus.resolve(problem.ref), isNotNull);
      }
    });
  });

  group('A problem the mapper must refuse', () {
    JsonReader read(Map<String, Object?> json) =>
        JsonReader.root(json, file: 'test');
    Map<String, Object?> localized(String value) => <String, Object?>{
      'en': value,
      'fa': value,
    };
    Map<String, Object?> stance(String id) => <String, Object?>{
      'id': id,
      'name': localized('A position'),
      'summary': localized('That something is so.'),
    };
    Map<String, Object?> problem(List<Object?> positions) => <String, Object?>{
      'id': 'test-problem',
      'name': localized('A problem'),
      'oneLine': localized('Something is disputed.'),
      'question': localized('Is it so?'),
      'positions': positions,
    };

    test('one with a single position', () {
      expect(
        () => ContentMappers.problem(read(problem(<Object?>[stance('a')]))),
        throwsA(isA<ContentException>()),
      );
    });

    test('one with no positions at all', () {
      expect(
        () => ContentMappers.problem(read(problem(const <Object?>[]))),
        throwsA(isA<ContentException>()),
      );
    });

    test('one whose positions share an identifier', () {
      expect(
        () => ContentMappers.problem(
          read(problem(<Object?>[stance('a'), stance('a')])),
        ),
        throwsA(isA<ContentException>()),
        reason: 'the second would silently replace the first in any lookup',
      );
    });

    test('two positions with distinct ids are fine', () {
      final parsed = ContentMappers.problem(
        read(problem(<Object?>[stance('a'), stance('b')])),
      );
      expect(parsed.positions, hasLength(2));
      expect(parsed.ref.kind, EntityKind.problem);
    });
  });

  test('the problems file is shipped with the app', () {
    // A content file the bundle does not carry loads in tests, which read the
    // filesystem, and fails on a device, which cannot.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/content/'));
    expect(File(AssetKnowledgeRepository.problemsFile).existsSync(), isTrue);
  });
}
