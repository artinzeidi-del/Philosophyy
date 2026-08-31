import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marking an article read must not produce a library with nothing in it.
///
/// ## The defect this is written against
///
/// `UserLibrary.isEmpty` counts read marks and mastered facts, and `itemCount`
/// counts read marks as things the reader made. The library screen renders
/// neither. So a reader who ticks "I have read this" at the foot of an article
/// and saves nothing else has a library that is not empty and has nothing to
/// draw: the screen takes the non-empty branch and lists bookmarks, positions,
/// highlights and notes, all of which are empty, and the reader gets a blank
/// page with not even the invitation the empty state would have given them.
///
/// The same happens after answering quiz questions, which bank mastered facts.
///
/// Marking an article read is a prominent control and needs no bookmark first,
/// so this is an ordinary path, not a corner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpLibrary(WidgetTester tester, UserLibrary library) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            PreferencesStore(preferences),
          ),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(library),
          initialRouteProvider.overrideWithValue(AppRouter.library),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  const thales = EntityRef(EntityKind.philosopher, 'thales');

  testWidgets('an article marked read is listed in the library', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      UserLibrary(
        readMarks: <ReadMark>[
          ReadMark(target: thales, markedAt: DateTime(2024, 5, 1)),
        ],
      ),
    );

    expect(
      find.text('Thales'),
      findsWidgets,
      reason: 'the reader marked it read and the library shows nothing at all',
    );
  });

  testWidgets('a library holding only mastered facts still says something', (
    tester,
  ) async {
    // Answering a quiz question banks a fact and creates nothing else. The
    // screen has no section for facts, so the honest thing is the invitation.
    await pumpLibrary(
      tester,
      const UserLibrary(masteredFacts: <String>{'tradition:thales'}),
    );

    // Nothing here is listable, so the reader should get the invitation the
    // empty library gives — not a heading over an empty page.
    expect(find.textContaining('saved'), findsWidgets);
    expect(find.text('Nothing saved'), findsNothing);
  });

  testWidgets('a reader who has saved nothing still gets the invitation', (
    tester,
  ) async {
    await pumpLibrary(tester, UserLibrary.empty);
    expect(find.textContaining('saved'), findsWidgets);
  });
}
