import 'dart:convert';
import 'dart:io';

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

/// One test per *kind* of defect this project has actually shipped.
///
/// ## Why this file exists
///
/// Every round of review found new defects, and each round found them with a
/// new instrument: screenshots caught a layout sized by its content, driving
/// the controls caught a chip that did nothing, watching the network caught a
/// character with no glyph that made the app fetch a font from Google. The
/// instruments kept finding things because each one looked at something the
/// others could not see — not because the code kept getting worse.
///
/// Fixing an instance closes an instance. These close the *class*, so that the
/// same kind of defect cannot come back quietly in a screen nobody thought to
/// look at. Each test below names the defect it was written for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pump(
    WidgetTester tester,
    String route, {
    Size size = const Size(1280, 900),
    String? language,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(
      language == null
          ? const <String, Object>{}
          : <String, Object>{'flutter.settings.language': language},
    );
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

  group('Nothing on screen is inert', () {
    // Written after two of them. The tag chips naming an entry's tradition
    // were drawn on every article and did nothing, which mattered most on the
    // forty-eight philosopher pages that had no other link. Then fifty-eight
    // of the seventy-six glossary cards turned out to answer a press with
    // nothing while looking exactly like the eighteen that opened.
    //
    // A control that does nothing is invisible to the compiler, to the
    // analyzer and to a test that only asks whether the screen renders.
    for (final entry in <String, String>{
      'home': AppRouter.home,
      'explore': AppRouter.explore,
      'glossary': AppRouter.glossary,
      'quiz': AppRouter.quiz,
      'settings': AppRouter.settings,
      'primer': AppRouter.primer,
    }.entries) {
      testWidgets('${entry.key}: every tappable thing responds', (
        tester,
      ) async {
        await pump(tester, entry.value);

        final inert = <String>[];
        for (final element in find.byType(InkWell).evaluate()) {
          final inkWell = element.widget as InkWell;
          final hasCallback =
              inkWell.onTap != null ||
              inkWell.onLongPress != null ||
              inkWell.onDoubleTap != null;
          if (hasCallback) continue;
          // An InkWell with no callback at all is either decoration that
          // should not be an InkWell, or a control someone forgot to wire.
          inert.add(_describe(element));
        }

        expect(
          inert,
          isEmpty,
          reason:
              'these look pressable on ${entry.key} and do nothing:\n  '
              '${inert.join('\n  ')}',
        );
      });
    }
  });

  group('One style, not two', () {
    // Written after the floating bar and the desktop rail drew the selected
    // destination differently: the bar had the lit sweep from the reference,
    // the rail had a flat container fill. The product said "you are here" one
    // way on a phone and another on a desktop, and nothing failed because
    // each was internally consistent.
    //
    // Both now take the decoration from `Glass.active`. This asserts they
    // still agree, by comparing what the two actually paint.
    testWidgets('the selected destination looks the same at any width', (
      tester,
    ) async {
      Future<BoxDecoration> selectedDecoration(Size size) async {
        await pump(tester, AppRouter.home, size: size);
        // The lit surface is the only decoration on the navigation carrying a
        // gradient; everything else there is a flat fill or nothing.
        final decorations = find
            .byType(AnimatedContainer)
            .evaluate()
            .map((element) => (element.widget as AnimatedContainer).decoration)
            .whereType<BoxDecoration>()
            .where((decoration) => decoration.gradient != null)
            .toList();
        expect(
          decorations,
          isNotEmpty,
          reason: 'nothing on the navigation is lit at $size',
        );
        return decorations.first;
      }

      final phone = await selectedDecoration(const Size(390, 844));
      final desktop = await selectedDecoration(const Size(1280, 900));

      expect(
        phone.gradient,
        desktop.gradient,
        reason:
            'the selected destination is lit differently on a phone and on a '
            'desktop, so the two navigations have drifted apart again',
      );
      expect(phone.boxShadow?.length, desktop.boxShadow?.length);
    });
  });

  group('Nothing is written and then dropped', () {
    test('every translated string is used somewhere', () {
      // Two strings sat translated in both languages and referenced nowhere:
      // one described a card that reopens the last entry read, a feature that
      // does not exist. A dead string is a promise in the repository that the
      // product does not keep, and it survives every other check.
      final english = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final keys = english.keys.where((key) => !key.startsWith('@'));

      final source = StringBuffer();
      for (final directory in <String>['lib', 'test']) {
        for (final entry in Directory(directory).listSync(recursive: true)) {
          if (entry is! File || !entry.path.endsWith('.dart')) continue;
          if (entry.path.contains('/generated/')) continue;
          source.write(entry.readAsStringSync());
        }
      }
      final text = source.toString();

      final unused = keys
          .where((key) => !RegExp('\\b$key\\b').hasMatch(text))
          .toList();
      expect(
        unused,
        isEmpty,
        reason:
            'translated into both languages and referenced nowhere: '
            '${unused.join(', ')}',
      );
    });

    test('the two translations carry exactly the same keys', () {
      final english = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final persian = jsonDecode(
        File('lib/l10n/app_fa.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      Set<String> keysOf(Map<String, dynamic> arb) =>
          arb.keys.where((key) => !key.startsWith('@')).toSet();

      expect(
        keysOf(english).difference(keysOf(persian)),
        isEmpty,
        reason: 'English keys with no Persian',
      );
      expect(
        keysOf(persian).difference(keysOf(english)),
        isEmpty,
        reason: 'Persian keys with no English',
      );
    });
  });
}

/// A description of a widget useful enough to find it in the source.
String _describe(Element element) {
  final parts = <String>[];
  element.visitAncestorElements((ancestor) {
    parts.add(ancestor.widget.runtimeType.toString());
    return parts.length < 4;
  });
  return '${element.widget.runtimeType} inside ${parts.join(' < ')}';
}
