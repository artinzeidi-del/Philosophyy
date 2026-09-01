import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/errors/content_exception.dart';
import 'package:philosophyy/data/content/content_mappers.dart';
import 'package:philosophyy/data/content/json_reader.dart';
import 'package:philosophyy/domain/entities/relation.dart';

/// What the content mapper refuses to load.
///
/// The corpus is checked from end to end by `content_integrity_test.dart`, but
/// that suite can only see content that parsed. Anything the mapper rejects
/// outright never reaches it, so the rejections themselves were untested — and
/// a rule enforced nowhere but in a `reader.invalid` call is a rule nobody can
/// see is still working. Each case below is a shape the corpus must never be
/// allowed to take.
void main() {
  JsonReader read(Map<String, Object?> json) =>
      JsonReader.root(json, file: 'test');

  Map<String, Object?> localized(String value) => <String, Object?>{
    'en': value,
    'fa': value,
  };

  Map<String, Object?> argument({
    List<Object?>? premises,
    List<Object?>? objections,
    String? attribution,
    Object? attributionNote,
  }) => <String, Object?>{
    'id': 'test-argument',
    'name': localized('An argument'),
    'oneLine': localized('That something follows.'),
    'premises':
        premises ??
        <Object?>[
          <String, Object?>{'id': 'p1', 'text': localized('A premise.')},
        ],
    'conclusion': <String, Object?>{
      'id': 'c',
      'text': localized('A conclusion.'),
    },
    'objections': ?objections,
    'attribution': ?attribution,
    'attributionNote': ?attributionNote,
  };

  group('An argument the corpus must not contain', () {
    test('one with no premises at all', () {
      expect(
        () => ContentMappers.argument(read(argument(premises: <Object?>[]))),
        throwsA(isA<ContentException>()),
        reason: 'a conclusion with nothing before it is an assertion',
      );
    });

    test('an objection aimed at a step that is not there', () {
      expect(
        () => ContentMappers.argument(
          read(
            argument(
              objections: <Object?>[
                <String, Object?>{
                  'id': 'o1',
                  'text': localized('That premise fails.'),
                  'targets': <String>['p9'],
                },
              ],
            ),
          ),
        ),
        throwsA(isA<ContentException>()),
        reason:
            'an objection pointing at a premise that was renamed or removed '
            'leaves the reader with a dangling argument',
      );
    });

    test('a qualified attribution that does not say why', () {
      expect(
        () => ContentMappers.argument(read(argument(attribution: 'contested'))),
        throwsA(isA<ContentException>()),
        reason: 'a mark the reader cannot act on is decoration',
      );
    });
  });

  group('An argument the corpus may contain', () {
    test('a qualified attribution with its reason', () {
      final parsed = ContentMappers.argument(
        read(
          argument(
            attribution: 'probable',
            attributionNote: localized('The text is a later report.'),
          ),
        ),
      );
      expect(parsed.attribution, RelationConfidence.probable);
      expect(parsed.hasSettledAttribution, isFalse);
      expect(parsed.attributionNote, isNotNull);
    });

    test('an unmarked attribution is taken as accepted', () {
      final parsed = ContentMappers.argument(read(argument()));
      expect(parsed.attribution, RelationConfidence.accepted);
      expect(parsed.hasSettledAttribution, isTrue);
    });

    test('an objection aimed at a step that exists', () {
      final parsed = ContentMappers.argument(
        read(
          argument(
            objections: <Object?>[
              <String, Object?>{
                'id': 'o1',
                'text': localized('That premise fails.'),
                'targets': <String>['p1'],
              },
            ],
          ),
        ),
      );
      expect(parsed.objectionsTo('p1'), hasLength(1));
      expect(parsed.generalObjections, isEmpty);
    });
  });
}
