import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/features/home/rank_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The cards on the front page are all the same width.
///
/// ## The defect this is written against
///
/// The home screen states its own layout rule: prose keeps the reading measure
/// and cards take the content measure. The rank banner is a card — it sits
/// between the quotation card and the section grid — and it had been wrapped in
/// a `ReadingColumn` anyway. On a desktop window that made it narrower than the
/// card above it and the cards below it, so one page showed three different
/// widths and the banner's trailing edge lined up with nothing.
///
/// Nothing caught it. It is not an overflow, it is not a contrast failure, and
/// at phone width all three measures collapse to the same number so every
/// widget test in the suite agreed. It was found by looking at a screenshot of
/// a 1440-point window.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final store = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(store),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(AppRouter.home),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in <Size>[
    const Size(1440, 900),
    const Size(1024, 768),
    const Size(834, 1112),
  ]) {
    testWidgets('at ${size.width.toInt()} the banner matches the cards', (
      tester,
    ) async {
      await pumpHome(tester, size);

      expect(find.byType(RankBanner), findsOneWidget);
      final banner = tester.getSize(find.byType(RankBanner)).width;

      // Every block on this page is wrapped in an EntranceAnimation, and the
      // ones holding cards take the content measure. The widest of them is
      // that measure, so the banner has to match it.
      final blocks = find.byType(EntranceAnimation);
      expect(blocks, findsWidgets, reason: 'the home page did not build');
      var widest = 0.0;
      for (var i = 0; i < tester.widgetList(blocks).length; i++) {
        final w = tester.getSize(blocks.at(i)).width;
        if (w > widest) widest = w;
      }

      expect(
        banner,
        closeTo(widest, 1),
        reason:
            'the rank banner is ${banner.toStringAsFixed(0)} wide and the '
            'content measure on this page is ${widest.toStringAsFixed(0)} — '
            'the front page is showing two different measures',
      );
    });
  }
}
