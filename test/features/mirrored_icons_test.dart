import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An arrow that means "forward" has to point the way the reader is going.
///
/// ## The defect this is written against
///
/// The quotation card on the home screen ends with a diagonal arrow saying the
/// card opens the entry. In Persian the card mirrors — the attribution moves to
/// the right, the arrow moves to the left — but the arrow went on pointing up
/// and to the right, out of the corner the reader has already read past.
///
/// It survived because the two chevrons beside it are correct for a reason that
/// has nothing to do with this app: the framework declares `chevron_right` with
/// `matchTextDirection: true` and declares `arrow_outward_rounded` without it.
/// So one directional glyph on the page mirrored and one did not, and the
/// difference is invisible unless you put the two screenshots side by side.
///
/// The test asserts the rendered geometry rather than the widget used to get
/// it: in Persian the arrow's painted transform must flip horizontally, and in
/// English it must not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpHome(WidgetTester tester, String language) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.settings.language': language,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(AppRouter.home),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Whether [icon] is painted mirrored, however that mirroring is achieved.
  bool isMirrored(WidgetTester tester, IconData icon) {
    final finder = find.byIcon(icon);
    expect(finder, findsOneWidget, reason: 'the arrow is not on the page');
    final box = tester.renderObject<RenderBox>(finder);
    final matrix = box.getTransformTo(null);
    // A horizontal flip is the only thing that makes this entry negative.
    return matrix.entry(0, 0) < 0;
  }

  testWidgets('the quotation arrow points the reader\'s way in Persian', (
    tester,
  ) async {
    await pumpHome(tester, 'fa');
    expect(isMirrored(tester, Icons.arrow_outward_rounded), isTrue);
  });

  testWidgets('the quotation arrow is left alone in English', (tester) async {
    await pumpHome(tester, 'en');
    expect(isMirrored(tester, Icons.arrow_outward_rounded), isFalse);
  });
}
