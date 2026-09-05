import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/errors/content_exception.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';

/// A bundle that serves the real content files, with named ones replaced.
///
/// The defect this exists for was made by hand: a script restored a backup
/// into the wrong path, so quotes.json arrived holding the works file. Every
/// key the quotation loader wanted was absent, the loader read that as an
/// empty array, and the corpus came up with two hundred and thirty-eight
/// quotations missing. Nothing failed. The only sign was a documentation test
/// complaining that the README did not say "0 quotations".
class _PatchedBundle extends CachingAssetBundle {
  _PatchedBundle(this.replacements);

  final Map<String, String> replacements;

  @override
  Future<ByteData> load(String key) async {
    final replacement = replacements[key];
    if (replacement != null) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(replacement)));
    }
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loading the corpus', () {
    test('refuses a file whose collection key is missing', () async {
      final repository = AssetKnowledgeRepository(
        bundle: _PatchedBundle(<String, String>{
          // What the accident produced: valid JSON, right shape, wrong key.
          AssetKnowledgeRepository.quotesFile: jsonEncode(<String, Object?>{
            'works': <Object?>[],
          }),
        }),
      );

      await expectLater(
        repository.load(),
        throwsA(
          isA<ContentException>()
              .having((e) => e.file, 'file', contains('quotes.json'))
              .having((e) => e.message, 'message', contains('quotes')),
        ),
      );
    });

    test('refuses a file whose collection is present but empty', () async {
      final repository = AssetKnowledgeRepository(
        bundle: _PatchedBundle(<String, String>{
          AssetKnowledgeRepository.argumentsFile: jsonEncode(<String, Object?>{
            'arguments': <Object?>[],
          }),
        }),
      );

      await expectLater(repository.load(), throwsA(isA<ContentException>()));
    });

    test('loads the shipped corpus through the same path', () async {
      final corpus = await const AssetKnowledgeRepository().load();
      expect(corpus.quotes, isNotEmpty);
      expect(corpus.arguments, isNotEmpty);
      expect(corpus.problems, isNotEmpty);
    });
  });
}
