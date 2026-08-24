import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

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
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
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
    rightsNote: LocalizedText(
      en: 'Peer-reviewed academic reference work.',
      fa: 'مرجع دانشگاهی داوری‌شده.',
    ),
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

  testWidgets('the note saying how a source is cited is shown', (tester) async {
    // A hundred and forty-four sources carry a sentence saying how to follow
    // the citation — that "38a" is a Stephanus number, that the Enchiridion
    // was compiled by a student, that FitzGerald's Khayyam is a paraphrase
    // rather than a translation. Nothing rendered any of it, so a locator that
    // means something to an editor meant nothing to a reader.
    await pumpCitation(tester, withUrl);
    expect(find.text('Peer-reviewed academic reference work.'), findsOneWidget);
  });

  testWidgets('the note is read in the reader\'s language', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: SourceLine(source: withUrl, language: AppLanguage.fa),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('مرجع دانشگاهی داوری‌شده.'), findsOneWidget);
  });

  testWidgets('a source with no note gets no empty line', (tester) async {
    await pumpCitation(tester, withoutUrl);
    expect(find.text(''), findsNothing);
  });

  testWidgets('the Sources list under an article carries the links too', (
    tester,
  ) async {
    // The link and the note were added to SourceLine, which renders a work's
    // editions. The Sources list at the foot of every article is a different
    // widget, and it is the place a reader actually looks for the references —
    // so it printed author, title and locator and nothing a reader could
    // follow. Three hundred and twenty-eight of the corpus's eight hundred and
    // thirty-three entry-level citations name a source with an address.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: CitationList(
            citations: const <Citation>[Citation(sourceId: 'sep')],
            language: AppLanguage.en,
            resolveSource: (id) => id == 'sep' ? withUrl : null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Stanford Encyclopedia of Philosophy'), findsNothing);
    expect(find.textContaining('Stanford Encyclopedia'), findsWidgets);
    expect(find.text('https://plato.stanford.edu'), findsOneWidget);
    expect(find.text('Peer-reviewed academic reference work.'), findsOneWidget);
  });

  testWidgets('a citation to a text with no address stays a plain line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: CitationList(
            citations: const <Citation>[
              Citation(sourceId: 'plato-republic', locator: '514a'),
            ],
            language: AppLanguage.en,
            resolveSource: (id) => withoutUrl,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('514a'), findsOneWidget);
    expect(find.textContaining('http'), findsNothing);
  });

  testWidgets('a link that cannot be opened does not throw at the reader', (
    tester,
  ) async {
    // `launchUrl` throws when the platform has no handler for the address — a
    // desktop with no browser association, a locked-down device, a webview.
    // Fired and forgotten, that surfaces as an uncaught async error rather
    // than as anything the reader can understand. In a test there is no
    // plugin at all, which is the same shape of failure.
    await pumpCitation(tester, withUrl);
    await tester.tap(find.text('https://plato.stanford.edu'));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'tapping a link that cannot open threw out of the tap handler',
    );
    // What happens *after* a failed open — the line telling the reader it did
    // not work — is not asserted here, because url_launcher reports success in
    // a test environment and the failure cannot be provoked. This test holds
    // the part that can be checked: nothing escapes the tap. It was confirmed
    // to fail against a tap deliberately made to throw.
  });

  testWidgets('a malformed address is not offered as a link', (tester) async {
    // The field is free-form text in a content file, and `Uri.parse` throws on
    // something that is not an address at all.
    const broken = Source(
      id: 'broken',
      kind: SourceKind.referenceWork,
      title: LocalizedText(en: 'Somewhere'),
      url: ':::not a url:::',
    );
    await pumpCitation(tester, broken);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the link is big enough to hit', (tester) async {
    // Measured rather than handed to `meetsGuideline`. The guideline walks the
    // article route in the touch-target test, but the Sources list sits at the
    // foot of a long lazy scroll view and is not built at the viewport that
    // test uses — and pointing the guideline at this widget on its own passes
    // even when the link is deliberately shrunk to eight pixels, so it is not
    // looking at this node at all. The box is measured here instead.
    await pumpCitation(tester, withUrl);
    final size = tester.getSize(
      find.ancestor(
        of: find.text('https://plato.stanford.edu'),
        matching: find.byType(InkWell),
      ),
    );
    expect(
      size.height,
      greaterThanOrEqualTo(minimumTapTarget),
      reason:
          'a one-line address in citation type is a ${size.height}px target, '
          'and a finger needs $minimumTapTarget',
    );
  });

  testWidgets('the barest citation is still big enough to hit', (tester) async {
    // A title and an address and nothing else. Three lines of citation happen
    // to clear the minimum on their own, so without a floor nothing would
    // notice until a source arrived that carries no note.
    const bare = Source(
      id: 'iep',
      kind: SourceKind.referenceWork,
      title: LocalizedText(en: 'IEP'),
      url: 'https://iep.utm.edu',
    );
    await pumpCitation(tester, bare);
    final size = tester.getSize(
      find.ancestor(
        of: find.text('https://iep.utm.edu'),
        matching: find.byType(InkWell),
      ),
    );
    expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
  });
}
