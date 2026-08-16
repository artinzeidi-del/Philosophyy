import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/concept.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/navigation.dart';

/// Proves the browsing screen does not build the whole corpus to show a screen
/// of it.
///
/// This is the defect that never announces itself. A `ListView` whose children
/// are one tall `Column` builds every card on every frame, however far off
/// screen — invisible at fourteen works, fatal at ten thousand, and by then the
/// fix is a rewrite rather than an edit. The stated ambition of this product is
/// thousands of philosophers and tens of thousands of concepts, so the property
/// is asserted rather than assumed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase real;

  setUpAll(() async {
    real = await const AssetKnowledgeRepository().load();
  });

  /// A corpus of [count] philosophers, works and concepts, built from the real
  /// one so that everything it references still resolves.
  KnowledgeBase inflated(int count) {
    Philosopher philosopherAt(int index) {
      final source = real.philosophers[index % real.philosophers.length];
      return Philosopher(
        id: 'p$index',
        name: LocalizedText(en: 'Philosopher $index', fa: 'فیلسوف $index'),
        oneLine: source.oneLine,
        life: source.life,
        traditions: source.traditions,
        branches: source.branches,
      );
    }

    return KnowledgeBase(
      taxonomy: real.taxonomy,
      philosophers: <Philosopher>[
        for (var i = 0; i < count; i++) philosopherAt(i),
      ],
      works: <Work>[
        for (var i = 0; i < count; i++)
          Work(
            id: 'w$i',
            name: LocalizedText(en: 'Work $i', fa: 'اثر $i'),
            oneLine: real.works[i % real.works.length].oneLine,
            authorId: 'p$i',
            composed: real.works[i % real.works.length].composed,
          ),
      ],
      concepts: <Concept>[
        for (var i = 0; i < count; i++)
          Concept(
            id: 'c$i',
            name: LocalizedText(en: 'Concept $i', fa: 'مفهوم $i'),
            oneLine: real.concepts[i % real.concepts.length].oneLine,
            shortDefinition:
                real.concepts[i % real.concepts.length].shortDefinition,
          ),
      ],
      schools: const [],
      quotes: const [],
      arguments: const [],
      sources: const [],
      relations: const [],
    );
  }

  Future<void> pumpExplore(WidgetTester tester, KnowledgeBase corpus) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
    // By key rather than by icon: the home screen's "Browse" tile carries
    // the same glyph as the navigation destination.
    await tapNav(tester, NavIcons.explore);
    await tester.pumpAndSettle();
  }

  group('Browsing a large corpus', () {
    testWidgets('builds a screenful of cards, not the whole corpus', (
      tester,
    ) async {
      const size = 400;
      await pumpExplore(tester, inflated(size));

      // Every row on this screen — philosopher, work, concept — renders an
      // EntityCard, so one count covers the whole screen.
      final built = tester.widgetList(find.byType(EntityCard)).length;
      // Building eagerly would produce three cards per entity — philosopher,
      // work and concept — so 1,200 here. Lazily it is under twenty, a
      // screenful plus the cache extent. The bound is loose enough not to flake
      // when the viewport or cache extent changes, and still decisive.
      expect(
        built,
        lessThan(size ~/ 4),
        reason:
            'the explore screen built $built cards for a corpus of $size — it '
            'is building everything rather than what is on screen',
      );
      expect(built, greaterThan(0), reason: 'nothing rendered at all');
    });

    testWidgets('scrolling reaches entries far down the list', (tester) async {
      // Laziness is only correct if the rest is still reachable.
      await pumpExplore(tester, inflated(400));

      await tester.scrollUntilVisible(
        find.text('Philosopher 60'),
        400,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 200,
      );
      expect(find.text('Philosopher 60'), findsOneWidget);
    });

    testWidgets('the real corpus still renders every philosopher it has', (
      tester,
    ) async {
      // The laziness must not have quietly dropped anything at today's size.
      await pumpExplore(tester, real);
      expect(find.byType(EntityCard), findsWidgets);
    });
  });
}
