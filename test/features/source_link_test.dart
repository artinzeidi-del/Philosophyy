import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';

/// A citation the reader cannot follow is the appearance of sourcing.
///
/// ## The defect this is written against
///
/// Sources carry a `url`, and the citation line never rendered it. Every entry
/// resting on the Stanford Encyclopedia, the Internet Encyclopedia of
/// Philosophy or the Perseus Digital Library named the work and gave the reader
/// no way to reach it — in a product whose whole argument is that a reader
/// should be able to check what it says.
///
/// The rule is narrow on purpose. Most sources here are primary texts cited by
/// a canonical locator — a Stephanus number, a Bekker number — which is stable
/// across every edition and better than any link, so those carry no url and
/// must not sprout one. Only a source that records a url becomes a link.
void main() {
  Future<void> pumpCitation(WidgetTester tester, Source source) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceLine(source: source, language: AppLanguage.en),
        ),
      ),
    );
    await tester.pump();
  }

  const withUrl = Source(
    id: 'sep',
    kind: SourceKind.referenceWork,
    title: LocalizedText(en: 'Stanford Encyclopedia of Philosophy'),
    url: 'https://plato.stanford.edu',
  );

  const withoutUrl = Source(
    id: 'plato-republic',
    kind: SourceKind.primaryText,
    title: LocalizedText(en: 'Republic'),
    authors: <String>['Plato'],
  );

  testWidgets('a source with a url is a link the reader can follow', (
    tester,
  ) async {
    await pumpCitation(tester, withUrl);
    expect(find.text('https://plato.stanford.edu'), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
  });

  testWidgets('a text cited by canonical locator grows no link', (
    tester,
  ) async {
    await pumpCitation(tester, withoutUrl);
    expect(find.textContaining('http'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });
}
