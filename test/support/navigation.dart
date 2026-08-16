import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps a destination in the floating navigation bar.
///
/// Tests used to reach the tabs with `find.text('Library')`, and two changes
/// broke that at once: the home screen now has tiles carrying the same words,
/// so the finder matches twice, and the bar only shows the label of the
/// destination that is already selected, so scoping the finder to the bar
/// matches nothing. Both are properties of the design rather than defects, and
/// the fix belongs in one helper rather than in every test that navigates.
///
/// Each destination carries a key derived from a stable identifier, which does
/// not change with the language and is the same whether the shell rendered the
/// pill or the rail.
Future<void> tapNav(WidgetTester tester, String destination) async {
  final target = find.byKey(ValueKey<String>('nav-$destination'));
  expect(
    target,
    findsOneWidget,
    reason: 'no navigation destination "$destination" on screen',
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// The destination identifiers the shell declares.
abstract final class NavIcons {
  static const String home = 'home';
  static const String explore = 'explore';
  static const String search = 'search';
  static const String library = 'library';
  static const String settings = 'settings';
}
