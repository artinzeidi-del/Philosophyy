import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/glow_segments.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The depth control has to show which depth the reader is at.
///
/// ## The defect this is written against
///
/// Settings offers four reading levels and each maps to a content depth:
/// beginner to quick, intermediate to standard, advanced to in-depth, and
/// research to a fourth depth called research. Nothing in the corpus is
/// authored at that fourth depth, and nothing ever will be by accident — the
/// deepest layer anyone writes is "deep".
///
/// The article opened at the reader's preferred depth, raising it only when the
/// article had nothing that shallow, and never lowering it. The depth control
/// separately offers only the depths the article actually has. So a reader who
/// chose "Research" got a control showing three options with none of them lit:
/// the selected value was not among the segments, and the highlight is drawn
/// only when it is.
///
/// The content was right — every section is visible at a depth past the last
/// one authored — which is exactly why this survived. Nothing was missing; the
/// control simply stopped saying where the reader was.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpArticle(WidgetTester tester, LearningLevel level) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.settings.readingLevel': level.id,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue('/philosophers/thales'),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final level in LearningLevel.values) {
    testWidgets('the depth control shows a selection at the ${level.id} level', (
      tester,
    ) async {
      await pumpArticle(tester, level);

      final finder = find.byType(GlowSegments<ContentDepth>);
      expect(finder, findsOneWidget, reason: 'the depth control is not drawn');

      final control = tester.widget<GlowSegments<ContentDepth>>(finder);
      expect(
        control.segments.map((segment) => segment.value),
        contains(control.selected),
        reason:
            'the control is set to ${control.selected.id}, which is not one of '
            'the depths it offers, so no segment is lit',
      );
    });
  }

  test('no article is authored deeper than the deepest offered depth', () {
    // The clamp only holds while this is true. If a research layer is ever
    // written, the level and the control agree again and nothing needs doing —
    // but the assumption should fail loudly rather than silently.
    for (final entity in corpus.allEntities) {
      expect(
        entity.article.deepestAuthoredDepth.order,
        lessThanOrEqualTo(ContentDepth.deep.order),
        reason: '${entity.ref} is authored deeper than "deep"',
      );
    }
  });
}
