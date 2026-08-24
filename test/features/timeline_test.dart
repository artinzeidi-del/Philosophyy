import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/features/shared/timeline_band.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every entry carries the one picture the corpus can honestly draw.
///
/// ## What this is checking and why it matters
///
/// The product holds no portraits and will not invent any — a plausible
/// likeness of somebody nobody has a likeness of is the same defect as a
/// plausible citation. What it does hold, for every entry, is *when*: a life, a
/// date of composition, a period, or the span of the people who argued an idea.
///
/// So the promise is that no entry is left without one. That is only worth
/// making if it is checked against the shipped corpus rather than against a
/// fixture, because the failure mode is a single entry with a missing date
/// quietly rendering nothing where every other entry has something.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  group('The corpus can date everything', () {
    test('every philosopher has a life to draw', () {
      final undated = <String>[
        for (final philosopher in corpus.philosophers)
          if (!philosopher.life.isKnown) philosopher.id,
      ];
      expect(
        undated,
        isEmpty,
        reason: 'these philosophers would show no timeline: $undated',
      );
    });

    test('every work has a date of composition', () {
      final undated = <String>[
        for (final work in corpus.works)
          if (work.composed == null) work.id,
      ];
      expect(undated, isEmpty, reason: 'these works are undated: $undated');
    });

    test('every school has a period', () {
      final undated = <String>[
        for (final school in corpus.schools)
          if (school.period == null) school.id,
      ];
      expect(undated, isEmpty, reason: 'these schools are undated: $undated');
    });

    test('every concept names a philosopher who can be dated', () {
      // A concept has no date of its own. It is placed by the people who
      // argued it, so it needs at least one of them, and that one needs a life.
      final orphaned = <String>[
        for (final concept in corpus.concepts)
          if (!concept.philosopherIds.any(
            (id) => corpus.philosopher(id)?.life.isKnown ?? false,
          ))
            concept.id,
      ];
      expect(
        orphaned,
        isEmpty,
        reason: 'these ideas cannot be placed in time: $orphaned',
      );
    });
  });

  group('The band', () {
    test('bounds sit outside the data on both sides', () {
      final (low, high) = TimelineBand.boundsOf(const <int>[-624, -546, 1900]);
      expect(low, lessThan(-624));
      expect(high, greaterThan(1900));
    });

    test('a single year still produces a band with width', () {
      final (low, high) = TimelineBand.boundsOf(const <int>[400]);
      expect(high, greaterThan(low));
    });

    test('no data falls back to a sane range rather than dividing by zero', () {
      final (low, high) = TimelineBand.boundsOf(const <int>[]);
      expect(high, greaterThan(low));
    });
  });

  testWidgets('the band does not mirror in a right-to-left page', (
    tester,
  ) async {
    // Time is the one axis that does not flip. A Persian reader reads the page
    // right to left and still expects the earlier century to the left of the
    // later one — every timeline and dynasty chart printed in Persian is drawn
    // that way, and mirroring would put 2000 CE before 500 BCE.
    //
    // The painter never mirrors, so the labels under it must not either, which
    // takes a deliberate `Directionality` around them. This is here because
    // removing that wrapper looks like tidying up.
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 400,
              child: TimelineBand(
                span: HistoricalRange(
                  start: HistoricalYear(-624),
                  end: HistoricalYear(-546),
                ),
                others: const <int>[-2400, -600, 1900],
                caption: 'caption',
                startLabel: 'EARLIEST',
                endLabel: 'LATEST',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('EARLIEST')).dx,
      lessThan(tester.getCenter(find.text('LATEST')).dx),
      reason: 'the earliest year is not at the left end, but the band is',
    );
  });

  group('On the page', () {
    Future<void> open(WidgetTester tester, String route) async {
      tester.view.physicalSize = const Size(430, 932);
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
            initialRouteProvider.overrideWithValue(route),
          ],
          child: const PhilosophiaApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final entry in const <String, String>{
      '/philosophers/thales': 'a philosopher',
      '/works/republic': 'a work',
      '/concepts/veil-of-ignorance': 'an idea',
      '/schools/stoicism': 'a school',
    }.entries) {
      testWidgets('${entry.value} shows a band and says what it is', (
        tester,
      ) async {
        await open(tester, entry.key);
        final l10n = await AppL10n.delegate.load(const Locale('en'));

        expect(
          find.byType(TimelineBand),
          findsOneWidget,
          reason: '${entry.key} has no timeline',
        );
        expect(
          find.text(l10n.sectionWhen),
          findsOneWidget,
          reason: '${entry.key} draws a band with no heading over it',
        );

        // The caption is the part a screen reader gets and the part that makes
        // the picture mean anything, so an empty one is a failure.
        final band = tester.widget<TimelineBand>(find.byType(TimelineBand));
        expect(band.caption.trim(), isNotEmpty);
        expect(
          band.caption,
          isNot(contains('{')),
          reason: 'an unsubstituted placeholder reached the screen',
        );
      });
    }

    testWidgets('the edge labels name years the corpus reaches', (
      tester,
    ) async {
      // The labels were the padded bounds of the drawing, which printed years
      // no entry is dated to — "2574 BCE" on a corpus whose earliest entry is
      // 2400 BCE. An axis label is a claim about the data.
      await open(tester, '/philosophers/thales');
      final band = tester.widget<TimelineBand>(find.byType(TimelineBand));

      final anchors = <int>[
        for (final philosopher in corpus.philosophers)
          if (philosopher.life.sortAnchor case final HistoricalYear year)
            year.year,
      ]..sort();

      expect(band.startLabel, isNotNull);
      expect(band.endLabel, isNotNull);
      // The earliest and latest years the corpus actually holds, formatted.
      expect(band.startLabel, contains('${anchors.first.abs()}'));
      expect(band.endLabel, contains('${anchors.last.abs()}'));
    });
  });
}
