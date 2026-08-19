import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/app_theme.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/features/entity/entity_screen.dart';
import 'package:philosophyy/features/explore/explore_screen.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/navigation.dart';

/// Boots the real app against the real content.
///
/// Unit tests can all pass while the app fails to start. These tests answer the
/// question the unit tests cannot: does the thing run, in both languages and
/// both themes, and can a reader get from the home screen to an article and
/// back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  /// Pumps the app with the corpus already loaded.
  ///
  /// The corpus is injected rather than loaded through the provider because
  /// `pumpAndSettle` drives frames through fake time and cannot advance the
  /// real asset I/O the loader performs — the app would sit on its loading
  /// spinner, which animates forever, and the test would time out having proved
  /// nothing. Loading the real content once in `setUpAll` and handing it in
  /// keeps these tests running against the real corpus while making the widget
  /// tree deterministic.
  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final instance = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(instance),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Startup', () {
    testWidgets('the app boots and shows the home screen', (tester) async {
      await pumpApp(tester);

      expect(find.text('Philosophia'), findsWidgets);
      // The daily quotation is the first thing a reader meets. Asserted on the
      // text rather than on the widget type: the card it is drawn in has been
      // replaced once already, and what matters is that the reader sees a
      // quotation, not which class rendered it.
      // Which quotation appears is chosen by the date, so the test asks
      // whether any shareable one is on screen rather than repeating the
      // rotation logic and going stale with it.
      expect(
        corpus.quotes
            .where((quote) => quote.isShareable)
            .any((quote) => find.text(quote.text.en).evaluate().isNotEmpty),
        isTrue,
        reason: 'the home screen is showing no quotation at all',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow or layout error on a small phone', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders on a tablet-width screen', (tester) async {
      tester.view.physicalSize = const Size(1024 * 2, 1366 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Navigation', () {
    testWidgets('a tradition chip on an article opens Explore', (tester) async {
      // The chips naming an entry's tradition and branches were inert. That
      // was invisible to every test and to the compiler, and it mattered most
      // on the forty-eight philosopher pages that had no concepts, no works,
      // no school and no relations: from those, a reader had nowhere to go
      // but back.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);
      await tester.tap(find.byType(EntityCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(EntityScreen), findsOneWidget);

      final chip = find.byType(TagChip).first;
      expect(chip, findsOneWidget, reason: 'the article shows no tag chips');
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(
        find.byType(ExploreScreen),
        findsOneWidget,
        reason: 'tapping a tag chip did not open Explore',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a reader can open an article and come back', (tester) async {
      // A viewport tall enough that the "Start here" cards are on screen. The
      // default 800×600 test surface puts them below the fold, and scrolling
      // them into view is not what this test is about.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);

      await tester.tap(find.byType(EntityCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(EntityScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // And back again.
      final backButton = find.byType(BackButton);
      expect(backButton, findsWidgets, reason: 'no way back from the article');
      await tester.tap(backButton.first);
      await tester.pumpAndSettle();

      expect(find.byType(EntityScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every tab opens without error', (tester) async {
      await pumpApp(tester);

      for (final tab in <String>[
        NavIcons.explore,
        NavIcons.search,
        NavIcons.library,
        NavIcons.settings,
        NavIcons.home,
      ]) {
        await tapNav(tester, tab);
        expect(
          tester.takeException(),
          isNull,
          reason: 'opening the "$tab" tab threw',
        );
      }
    });

    testWidgets('search finds a philosopher and opens the article', (
      tester,
    ) async {
      await pumpApp(tester);

      await tapNav(tester, NavIcons.search);

      await tester.enterText(find.byType(TextField), 'Avicenna');
      await tester.pumpAndSettle();

      expect(find.byType(EntityCard), findsWidgets);
      await tester.tap(find.byType(EntityCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(EntityScreen), findsOneWidget);
      // The article opened is the right one.
      expect(find.textContaining('Ibn Sīnā'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'an unknown identifier shows the not-found state, not a crash',
      (tester) async {
        await pumpApp(tester);

        final context = tester.element(find.byType(Scaffold).first);
        final l10n = AppL10n.of(context);

        final router = ProviderScope.containerOf(context).read(routerProvider);
        unawaited(router.push('/philosophers/does-not-exist'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.notFoundTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Bilingual rendering', () {
    testWidgets('Persian renders right-to-left', (tester) async {
      await pumpApp(
        tester,
        preferences: <String, Object>{
          'flutter.${SettingsController.languageKey}': 'fa',
        },
      );

      final directionality = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(directionality.textDirection, TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });

    testWidgets('English renders left-to-right', (tester) async {
      await pumpApp(
        tester,
        preferences: <String, Object>{
          'flutter.${SettingsController.languageKey}': 'en',
        },
      );

      final directionality = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(directionality.textDirection, TextDirection.ltr);
    });

    testWidgets('Persian content is actually shown, not English', (
      tester,
    ) async {
      await pumpApp(
        tester,
        preferences: <String, Object>{
          'flutter.${SettingsController.languageKey}': 'fa',
        },
      );

      // A Persian string from the home screen, proving the localisation is
      // wired end to end rather than merely present in the ARB file.
      expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
    });

    testWidgets('an article renders in Persian without error', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        preferences: <String, Object>{
          'flutter.${SettingsController.languageKey}': 'fa',
        },
      );

      await tester.tap(find.byType(EntityCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(EntityScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Theming', () {
    testWidgets('the dark theme builds and renders', (tester) async {
      await pumpApp(
        tester,
        preferences: <String, Object>{
          'flutter.${SettingsController.themeKey}': 'dark',
        },
      );

      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both themes build for both languages', (tester) async {
      // Cheap guard against a theme that compiles but throws when assembled —
      // for example a text style referring to a font that is not registered.
      for (final language in AppLanguage.values) {
        expect(() => AppTheme.light(language), returnsNormally);
        expect(() => AppTheme.dark(language), returnsNormally);
      }
    });
  });
}
