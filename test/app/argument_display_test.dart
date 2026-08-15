import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/app_theme.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/features/entity/entity_screen.dart';
import 'package:philosophyy/features/shared/argument_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Proves the reconstructed arguments are reachable by a reader.
///
/// They were not. Twelve arguments were authored, parsed, and checked by the
/// integrity tests — every objection verified to point at a premise that
/// exists — and no screen in the product rendered one. Content with no surface
/// passes every test that looks at content and every test that looks at
/// screens, which is exactly why it needs a test that looks at both.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late AppL10n en;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    en = await AppL10n.delegate.load(const Locale('en'));
  });

  /// Pumps the real entity screen for [id], with the real corpus behind it.
  ///
  /// The screen rather than the whole app: routing is covered elsewhere, and
  /// what needs proving here is that this screen puts the argument on the page.
  Future<void> openPhilosopher(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(1100, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
        ],
        child: MaterialApp(
          theme: AppTheme.light(AppLanguage.en),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: <Locale>[
            for (final supported in AppLanguage.values) Locale(supported.code),
          ],
          home: EntityScreen(kind: EntityKind.philosopher, id: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Every argument has somewhere to be read', () {
    test('no argument is orphaned', () {
      // An argument reachable from neither a philosopher nor a work is content
      // the product cannot show, however well formed it is.
      final orphans = <String>[
        for (final argument in corpus.arguments)
          if (argument.proponentIds.isEmpty &&
              argument.opponentIds.isEmpty &&
              argument.workId == null)
            argument.id,
      ];
      expect(orphans, isEmpty, reason: 'unreachable arguments: $orphans');
    });

    test('every proponent and opponent page would list it', () {
      for (final argument in corpus.arguments) {
        for (final id in <String>[
          ...argument.proponentIds,
          ...argument.opponentIds,
        ]) {
          expect(
            corpus.argumentsBy(id).map((a) => a.id),
            contains(argument.id),
            reason: '${argument.id} is missing from $id',
          );
        }
      }
    });

    test('an opponent sees the argument listed as one they opposed', () {
      // Kant belongs on the ontological argument, and a reader arriving from
      // his entry must not be left thinking he proposed it.
      final onKant = corpus.argumentsBy('kant');
      expect(onKant, isNotEmpty);
      final ontological = onKant.firstWhere(
        (argument) => argument.id == 'ontological-argument',
      );
      expect(ontological.proponentIds, isNot(contains('kant')));
      expect(ontological.opponentIds, contains('kant'));
    });
  });

  group('The panel shows the shape of the argument', () {
    testWidgets('premises and conclusion render on the philosopher page', (
      tester,
    ) async {
      await openPhilosopher(tester, 'anselm');

      expect(find.byType(ArgumentPanel), findsWidgets);
      expect(find.text(en.argumentPremises.toUpperCase()), findsWidgets);
      expect(find.text(en.argumentConclusion.toUpperCase()), findsWidgets);
      expect(find.text('P1'), findsWidgets);
      expect(find.text('P3'), findsWidgets);
    });

    testWidgets('objections are collapsed until the reader asks', (
      tester,
    ) async {
      await openPhilosopher(tester, 'anselm');

      // Collapsed: the reply text is authored but not on screen yet.
      expect(find.text(en.argumentReply.toUpperCase()), findsNothing);

      await tester.tap(find.textContaining('objection').first);
      await tester.pumpAndSettle();

      expect(find.text(en.argumentReply.toUpperCase()), findsWidgets);
      // Each objection says which premise it denies, which is the whole reason
      // the structure is modelled rather than written as a paragraph.
      expect(find.textContaining('Denies'), findsWidgets);
    });

    testWidgets('an opponent is not shown as a proponent', (tester) async {
      await openPhilosopher(tester, 'kant');
      expect(find.byType(ArgumentPanel), findsWidgets);
      expect(find.text(en.argumentArguedAgainst), findsWidgets);
    });
  });
}
