import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';

/// Where the reader had got to, kept across leaving the article.
///
/// The position is written on a settle timer rather than on every scroll frame,
/// which is right — and the timer was cancelled on the way out without being
/// made, which was not. A reader who scrolled and went straight back lost the
/// scrolling they had just done, and the article reopened where they had been
/// the session before. Leaving is the moment the position matters most.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  testWidgets('reading on and leaving at once keeps the newer place', (
    tester,
  ) async {
    final target = corpus.philosophers.first.ref;

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryStore()),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(target.route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhilosophiaApp)),
    );
    double? saved() =>
        container.read(libraryProvider).positionFor(target)?.scrollOffset;

    final article = find.byType(CustomScrollView).first;

    // Read a little, and stop long enough for the settle to write.
    await tester.drag(article, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    final settled = saved();
    expect(
      settled,
      isNotNull,
      reason: 'stopping for a moment should record where the reader is',
    );

    // Read on, and leave straight away — inside the settle window.
    await tester.drag(article, const Offset(0, -600));
    await tester.pump();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(AppRouter.home);
    await tester.pumpAndSettle();

    expect(
      saved(),
      greaterThan(settled!),
      reason: 'the scrolling done just before leaving was thrown away',
    );
  });
}
