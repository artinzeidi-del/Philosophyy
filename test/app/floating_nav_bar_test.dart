import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/floating_nav_bar.dart';

/// Holds the floating navigation to the one property that is easy to lose.
void main() {
  const destinations = <NavBarDestination>[
    NavBarDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    NavBarDestination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
    ),
    NavBarDestination(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      label: 'Search',
    ),
    NavBarDestination(
      icon: Icons.bookmark_border,
      selectedIcon: Icons.bookmark,
      label: 'Library',
    ),
    NavBarDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  /// The width the label actually occupies in the row.
  ///
  /// Not the `Text`'s own width: an unselected label keeps its intrinsic size
  /// and is collapsed by the `ClipRect` around it, so measuring the `Text`
  /// reports the width it *would* have had.
  double labelWidth(WidgetTester tester, String label) => tester
      .getSize(
        find.ancestor(of: find.text(label), matching: find.byType(ClipRect)),
      )
      .width;

  Future<void> pump(
    WidgetTester tester, {
    int selected = 0,
    ValueChanged<int>? onSelected,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          bottomNavigationBar: FloatingNavBar(
            selectedIndex: selected,
            onSelected: onSelected ?? (_) {},
            destinations: destinations,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the bar is a bar, not the whole screen', (tester) async {
    // This is not a hypothetical. `AnimatedAlign` was given a `widthFactor` to
    // collapse the unselected labels and no `heightFactor` — and `Align` only
    // shrink-wraps an axis it has a factor for, so it took the tallest box on
    // offer. Every ancestor sized to its child, so the bar filled the entire
    // screen and the app rendered as one black rectangle. Nothing else caught
    // it: the widget tree was correct, every test still passed, and it was
    // visible only in a screenshot.
    await pump(tester);
    final height = tester.getSize(find.byType(FloatingNavBar)).height;
    expect(
      height,
      lessThan(120),
      reason: 'the navigation bar has grown to $height logical pixels',
    );
    expect(height, greaterThan(48), reason: 'the bar has collapsed');
  });

  testWidgets('every destination is reachable and reports its index', (
    tester,
  ) async {
    final tapped = <int>[];
    await pump(tester, onSelected: tapped.add);

    // Found by semantics label rather than by icon: the selected destination
    // swaps its outline icon for the filled one, so searching by the outline
    // finds nothing for whichever tab is current.
    for (var i = 0; i < destinations.length; i++) {
      await tester.tap(find.bySemanticsLabel(destinations[i].label));
    }
    expect(tapped, <int>[0, 1, 2, 3, 4]);
  });

  testWidgets('only the selected destination shows its label', (tester) async {
    // Five labels at once is what forces the icons small enough to stop being
    // recognisable. The selected label is the only one a reader needs.
    //
    // Checked by painted width rather than by presence in the tree: the
    // unselected labels stay built, because collapsing their width is what
    // makes the selected one slide open instead of appearing. They are wrapped
    // in `ExcludeSemantics` so a screen reader is not handed all five.
    await pump(tester, selected: 2);
    expect(labelWidth(tester, 'Search'), greaterThan(0));
    for (final hidden in <String>['Home', 'Explore', 'Library', 'Settings']) {
      expect(
        labelWidth(tester, hidden),
        0,
        reason: '$hidden is showing its label while not selected',
      );
    }
  });

  testWidgets('a narrow phone drops the label rather than overflowing', (
    tester,
  ) async {
    // Five icons plus "Settings" overflowed a 320-wide row by 87 pixels, and
    // Persian's «تنظیمات» is wider still. Below the threshold the bar keeps
    // the icons and drops the label; the selected pill still says where you
    // are.
    await pump(tester, selected: 4, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
    expect(labelWidth(tester, 'Settings'), 0);

    // And it comes back when there is room for it.
    await pump(tester, selected: 4, size: const Size(430, 900));
    expect(labelWidth(tester, 'Settings'), greaterThan(0));
  });
}
