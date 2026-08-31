import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/floating_nav_bar.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';

/// The navigation bar reads correctly in both directions.
///
/// The selected destination shows its label beside its icon, and the space
/// between the two was fixed to the label's left. In Persian the row runs the
/// other way, so that space fell on the far side of the label and the text sat
/// flush against the icon — measured at a gap of 0 where it should have been 8,
/// with 8 stranded on the outside.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Rect rectOf(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  for (final language in <String>['en', 'fa']) {
    testWidgets('in $language the label is spaced off its own icon', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(
              InMemoryStore(<String, String>{'settings.language': language}),
            ),
            corpusProvider.overrideWith((ref) => corpus),
            initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          ],
          child: const PhilosophiaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Every destination keeps its label in the tree — that is what lets the
      // selected one slide open rather than appear — so the one on show is the
      // one whose clip has been given a width.
      final labels = find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.byType(Text),
      );
      final shown = <Finder>[
        for (var index = 0; index < labels.evaluate().length; index++)
          if (rectOf(
                tester,
                find
                    .ancestor(
                      of: labels.at(index),
                      matching: find.byType(ClipRect),
                    )
                    .first,
              ).width >
              0)
            labels.at(index),
      ];
      expect(
        shown,
        hasLength(1),
        reason: 'exactly one destination is selected, so one label is shown',
      );

      final label = shown.single;
      final row = find.ancestor(of: label, matching: find.byType(Row)).first;
      final icon = find.descendant(of: row, matching: find.byType(Icon)).first;

      final textRect = rectOf(tester, label);
      final iconRect = rectOf(tester, icon);

      final gap = iconRect.left > textRect.right
          ? iconRect.left - textRect.right
          : textRect.left - iconRect.right;

      expect(
        gap,
        closeTo(Spacing.sm, 0.5),
        reason:
            'the label and its icon are $gap apart in $language; the space '
            'belongs between them, not on the far side of the label',
      );
    });
  }

  for (final language in <String>['en', 'fa']) {
    testWidgets('in $language the label opens from beside its icon', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(
              InMemoryStore(<String, String>{'settings.language': language}),
            ),
            corpusProvider.overrideWith((ref) => corpus),
            initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          ],
          child: const PhilosophiaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Move to another destination and stop half way through the slide, where
      // only part of the label has been revealed. The part revealed has to be
      // the end nearest the icon; anchored to the left it was the far end in
      // Persian, so the label appeared to grow away from what it names.
      await tester.tap(
        find
            .descendant(
              of: find.byType(FloatingNavBar),
              matching: find.byIcon(Icons.explore_outlined),
            )
            .first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final labels = find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.byType(Text),
      );
      Finder? opening;
      late Rect clipRect;
      for (var index = 0; index < labels.evaluate().length; index++) {
        final clip = find
            .ancestor(of: labels.at(index), matching: find.byType(ClipRect))
            .first;
        final rect = rectOf(tester, clip);
        // Against the padded box, not the text: the clip holds both, and the
        // padding is exactly what is being placed correctly or not.
        final full = rectOf(
          tester,
          find
              .ancestor(of: labels.at(index), matching: find.byType(Padding))
              .first,
        ).width;
        if (rect.width > 1 && rect.width < full - 1) {
          opening = labels.at(index);
          clipRect = rect;
          break;
        }
      }
      expect(
        opening,
        isNotNull,
        reason: 'a label should be part way open half a beat into the move',
      );

      final textRect = rectOf(
        tester,
        find.ancestor(of: opening!, matching: find.byType(Padding)).first,
      );
      final row = find.ancestor(of: opening, matching: find.byType(Row)).first;
      final iconRect = rectOf(
        tester,
        find.descendant(of: row, matching: find.byType(Icon)).first,
      );

      // The clip holds the end of the label that faces the icon.
      final iconIsBefore = iconRect.center.dx < textRect.center.dx;
      final held = iconIsBefore
          ? (clipRect.left - textRect.left).abs()
          : (clipRect.right - textRect.right).abs();
      expect(
        held,
        lessThan(1),
        reason: 'the label opened from the end away from its icon in $language',
      );
    });
  }
}
