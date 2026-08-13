import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';

/// Holds the motion system to its accessibility promise.
///
/// An animation setting honoured by most of an interface is not honoured at
/// all: the one screen that ignores it is the one that causes the headache.
/// These tests assert that every animated primitive collapses to nothing when
/// the platform reports reduced motion, and that it still animates when it does
/// not — because a "fix" that simply disables the animations everywhere would
/// otherwise pass silently.
void main() {
  /// Wraps [child] in a tree that reports a reduced-motion preference.
  Widget wrap(Widget child, {required bool reduceMotion}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Material(child: child),
    ),
  );

  /// The opacity currently applied to the entrance animation's content.
  double opacityOf(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('content')),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  const content = SizedBox(
    key: ValueKey<String>('content'),
    width: 100,
    height: 20,
  );

  group('Motion.isReduced', () {
    testWidgets('reads the platform preference', (tester) async {
      late bool reduced;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              reduced = Motion.isReduced(context);
              return const SizedBox();
            },
          ),
          reduceMotion: true,
        ),
      );
      expect(reduced, isTrue);
    });

    testWidgets('collapses a duration to zero when motion is reduced', (
      tester,
    ) async {
      late Duration duration;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              duration = Motion.duration(context, MotionTokens.moderate);
              return const SizedBox();
            },
          ),
          reduceMotion: true,
        ),
      );
      expect(duration, Duration.zero);
    });

    testWidgets('leaves the duration alone otherwise', (tester) async {
      late Duration duration;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              duration = Motion.duration(context, MotionTokens.moderate);
              return const SizedBox();
            },
          ),
          reduceMotion: false,
        ),
      );
      expect(duration, MotionTokens.moderate);
    });
  });

  group('EntranceAnimation', () {
    testWidgets('arrives instantly when motion is reduced', (tester) async {
      await tester.pumpWidget(
        wrap(
          const EntranceAnimation(index: 5, child: content),
          reduceMotion: true,
        ),
      );

      // Fully visible on the very first frame, with no pumping — a reader who
      // asked for no motion must not watch anything fade in, even briefly.
      expect(opacityOf(tester), 1.0);
    });

    testWidgets('animates in when motion is allowed', (tester) async {
      await tester.pumpWidget(
        wrap(const EntranceAnimation(child: content), reduceMotion: false),
      );

      expect(
        opacityOf(tester),
        lessThan(1.0),
        reason: 'the content should start hidden and rise into place',
      );

      await tester.pumpAndSettle();
      expect(opacityOf(tester), 1.0);
    });

    testWidgets('a later item in a list arrives after an earlier one', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: <Widget>[
              EntranceAnimation(child: SizedBox(height: 10)),
              EntranceAnimation(index: 4, child: content),
            ],
          ),
          reduceMotion: false,
        ),
      );

      // Part-way through the first item's arrival, the fifth has not started.
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacityOf(tester), 0.0);

      await tester.pumpAndSettle();
      expect(opacityOf(tester), 1.0);
    });

    testWidgets('the stagger is capped so long lists do not crawl', (
      tester,
    ) async {
      // Item 400 must not wait 400 × 55ms. The cap means it arrives on the same
      // schedule as item 8.
      await tester.pumpWidget(
        wrap(
          const EntranceAnimation(index: 400, child: content),
          reduceMotion: false,
        ),
      );

      await tester.pump(
        const Duration(milliseconds: 55 * 8) + MotionTokens.moderate,
      );
      expect(opacityOf(tester), 1.0);
    });

    testWidgets('settles cleanly, leaving no pending animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: <Widget>[
              EntranceAnimation(child: SizedBox(height: 10)),
              EntranceAnimation(index: 1, child: SizedBox(height: 10)),
              EntranceAnimation(index: 2, child: content),
            ],
          ),
          reduceMotion: false,
        ),
      );

      // pumpAndSettle throws on timeout, so reaching the assertion at all
      // proves the stagger is driven by animation rather than by timers that a
      // test cannot advance.
      await tester.pumpAndSettle();
      expect(opacityOf(tester), 1.0);
    });
  });

  group('PressableSurface', () {
    testWidgets('does not scale when motion is reduced', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          PressableSurface(
            onTap: () => taps++,
            child: const SizedBox(width: 200, height: 80, child: content),
          ),
          reduceMotion: true,
        ),
      );

      final target = find.byKey(const ValueKey('content'));
      final atRest = tester.getRect(target);

      final gesture = await tester.press(target);
      // The first pump lets the ticker record its start time; a single timed
      // pump would measure zero elapsed and prove nothing.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Measured on screen rather than read off the widget tree: what matters
      // is whether the reader sees movement, not how it was implemented.
      expect(
        tester.getRect(target),
        atRest,
        reason: 'the press response must be suppressed entirely',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      // Suppressing the animation must not suppress the tap itself.
      expect(taps, 1);
    });

    testWidgets('scales down under a press when motion is allowed', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          PressableSurface(
            onTap: () => taps++,
            child: const SizedBox(width: 200, height: 80, child: content),
          ),
          reduceMotion: false,
        ),
      );

      final target = find.byKey(const ValueKey('content'));
      final atRest = tester.getRect(target);

      final gesture = await tester.press(target);
      // The first pump lets the ticker record its start time; a single timed
      // pump would measure zero elapsed and prove nothing.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final pressed = tester.getRect(target);
      expect(
        pressed.width,
        lessThan(atRest.width),
        reason: 'the surface should visibly shrink under a finger',
      );
      // Small enough to read as physical rather than as an effect.
      expect(pressed.width / atRest.width, greaterThan(0.9));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(target), atRest);
      expect(taps, 1);
    });

    testWidgets('is announced as a button to assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          PressableSurface(
            onTap: () {},
            semanticLabel: 'Plato. Founded the Academy.',
            child: const SizedBox(width: 200, height: 80, child: content),
          ),
          reduceMotion: false,
        ),
      );

      expect(
        find.bySemanticsLabel('Plato. Founded the Academy.'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('Page transitions', () {
    testWidgets('the article transition is a no-op under reduced motion', (
      tester,
    ) async {
      late Widget produced;
      const child = SizedBox(key: ValueKey<String>('page'));

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              produced = PageTransitions.article(
                context,
                const AlwaysStoppedAnimation<double>(0.5),
                const AlwaysStoppedAnimation<double>(0),
                child,
              );
              return const SizedBox();
            },
          ),
          reduceMotion: true,
        ),
      );

      expect(
        identical(produced, child),
        isTrue,
        reason: 'the child must be returned untouched, not wrapped',
      );
    });

    testWidgets('the section transition is a no-op under reduced motion', (
      tester,
    ) async {
      late Widget produced;
      const child = SizedBox(key: ValueKey<String>('page'));

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              produced = PageTransitions.section(
                context,
                const AlwaysStoppedAnimation<double>(0.5),
                const AlwaysStoppedAnimation<double>(0),
                child,
              );
              return const SizedBox();
            },
          ),
          reduceMotion: true,
        ),
      );

      expect(identical(produced, child), isTrue);
    });

    testWidgets('the article transition animates when motion is allowed', (
      tester,
    ) async {
      late Widget produced;
      const child = SizedBox(key: ValueKey<String>('page'));

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              produced = PageTransitions.article(
                context,
                const AlwaysStoppedAnimation<double>(0.5),
                const AlwaysStoppedAnimation<double>(0),
                child,
              );
              return const SizedBox();
            },
          ),
          reduceMotion: false,
        ),
      );

      expect(produced, isA<FadeTransition>());
    });
  });
}
