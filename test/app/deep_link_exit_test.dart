import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reader who arrives on a page from outside has to be able to get in.
///
/// ## The defect this is written against
///
/// Articles, the glossary, the primer and the quiz sit outside the navigation
/// shell on purpose: a row of tabs at the foot of a page of prose competes with
/// the prose. That is right when the reader walked there from the home screen,
/// because the app bar then carries a back arrow.
///
/// It is wrong when they did not. Open a shared link to an article, or reload
/// the page you were reading, and the route is the first entry in the history:
/// `Navigator.canPop` is false, so `AppBar` draws no back arrow, and the screen
/// has no navigation bar either. The reader is on a page with no way off it
/// that is part of the app — only the browser's own back button, which on a
/// fresh tab goes nowhere. Every one of these screens shipped like that, and it
/// is the most likely way a new reader meets the product, because a link to one
/// article is the thing people send each other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpAt(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String homeHeadline(WidgetTester tester) =>
      AppL10n.of(tester.element(find.byType(Scaffold).first)).homeGreetingLead;

  for (final entry in <String, String>{
    'an article': '/philosophers/thales',
    'the glossary': AppRouter.glossary,
    'the primer': AppRouter.primer,
    'the quiz': AppRouter.quiz,
  }.entries) {
    testWidgets('${entry.key}, opened from a link, offers a way in', (
      tester,
    ) async {
      await pumpAt(tester, entry.value);

      final up = find.byTooltip('Home');
      expect(
        up,
        findsOneWidget,
        reason:
            '${entry.value} was opened with nothing to pop, so there is no '
            'back arrow — and without one the reader cannot reach the app',
      );

      final headline = homeHeadline(tester);
      await tester.tap(up);
      await tester.pumpAndSettle();
      expect(find.text(headline), findsOneWidget);
    });
  }

  testWidgets('walking to an article still gets a back arrow, not a home one', (
    tester,
  ) async {
    await pumpAt(tester, AppRouter.glossary);
    // Push an article on top, so there is something to pop.
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/philosophers/thales'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Home'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
