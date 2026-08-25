import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// Loads the corpus that actually ships and holds it to the content policy.
///
/// This is the test that stops the reference work from rotting. Content is
/// hand-authored across eight files that reference each other by identifier,
/// so a rename in one file silently breaks links in another — and a broken link
/// in a reference work is not a cosmetic problem, it is the product failing at
/// the one thing it exists to do.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  /// Every string of authored English that ships, with the field it came from.
  ///
  /// Read from the JSON rather than from the parsed corpus, because the rule
  /// below is about how a name is spelled in prose and the parsed objects
  /// have already thrown the field names away. `alsoKnownAs` is skipped: a
  /// plain-ASCII spelling listed there is deliberate, and it is what lets a
  /// reader who types «Anzaldua» into search find her.
  final englishStrings = <({String file, String path, String text})>[];

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();

    void walk(Object? node, String file, String path, String? key) {
      if (node is Map<String, Object?>) {
        for (final entry in node.entries) {
          if (entry.key == 'alsoKnownAs') continue;
          walk(entry.value, file, '$path.${entry.key}', entry.key);
        }
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          walk(node[i], file, '$path[$i]', key);
        }
      } else if (node is String && key == 'en') {
        englishStrings.add((file: file, path: path, text: node));
      }
    }

    for (final file in Directory(
      'assets/content',
    ).listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      walk(jsonDecode(file.readAsStringSync()), file.path, r'$', null);
    }
    expect(englishStrings, isNotEmpty);
  });

  group('The shipped corpus', () {
    test('loads and parses', () {
      expect(corpus.philosophers, isNotEmpty);
      expect(corpus.concepts, isNotEmpty);
      expect(corpus.works, isNotEmpty);
      expect(corpus.schools, isNotEmpty);
      expect(corpus.quotes, isNotEmpty);
      expect(corpus.arguments, isNotEmpty);
      expect(corpus.sources, isNotEmpty);
      expect(corpus.relations, isNotEmpty);
    });

    test('has no dangling cross-references', () {
      final violations = corpus.findIntegrityViolations();
      expect(
        violations,
        isEmpty,
        reason:
            'Every identifier in the corpus must resolve. Violations:\n'
            '${violations.join('\n')}',
      );
    });

    test('every entity is reachable by the route its reference produces', () {
      for (final entity in corpus.allEntities) {
        expect(
          corpus.exists(entity.ref),
          isTrue,
          reason: '${entity.ref} does not resolve back to itself',
        );
        expect(
          entity.ref.route,
          startsWith('/${entity.ref.kind.routeSegment}/'),
          reason: '${entity.ref} produces a malformed route',
        );
      }
    });

    test('every reference parses back from its canonical form', () {
      for (final entity in corpus.allEntities) {
        final round = EntityRef.tryParse(entity.ref.canonical);
        expect(
          round,
          entity.ref,
          reason: '${entity.ref.canonical} did not round-trip',
        );
      }
    });
  });

  group('Editorial policy', () {
    test('no two entries of a kind share a name', () {
      // Two entries with the same title are a defect wherever the reader
      // meets them. In a list they are indistinguishable; in search they
      // produce two identical rows; in the quiz one can be offered as a decoy
      // for the other, so a reader picking a correct answer is marked wrong.
      //
      // It has happened twice. Four Presocratics each had their surviving
      // quotations gathered under the English title "Fragments", and Beauvoir
      // ended up with two entries for The Second Sex — one of them added by a
      // batch that checked for a clashing identifier and not for a clashing
      // title. The identifier was different, so nothing complained.
      //
      // Scoped within a kind: a concept and a work may legitimately share a
      // name, and the reader can tell them apart by where they are.
      final problems = <String>[];
      for (final entry in <String, List<KnowledgeEntity>>{
        'philosopher': corpus.philosophers,
        'work': corpus.works,
        'concept': corpus.concepts,
        'school': corpus.schools,
      }.entries) {
        for (final language in AppLanguage.values) {
          final seen = <String, String>{};
          for (final entity in entry.value) {
            final name = entity.name.resolve(language);
            final earlier = seen[name];
            if (earlier != null) {
              problems.add(
                '${entry.key}: "$name" is the ${language.name} name of both '
                '$earlier and ${entity.id}',
              );
            }
            seen[name] = entity.id;
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no entry rests only on the encyclopedia', () {
      // A citation a reader cannot follow is not sourcing, it is the
      // appearance of sourcing. Fifty entries cited `sep` alone — no entry
      // named, no locator, nothing to look up — and every one of them had its
      // primary text already sitting in this same corpus.
      //
      // A tertiary source is a fine companion and a poor foundation. The rule
      // is that every entry must rest on at least one text somebody actually
      // wrote, not only on somebody's summary of it.
      const tertiary = <String>{'sep', 'iep', 'perseus'};
      final problems = <String>[];
      for (final entity in corpus.allEntities) {
        final cited = <String>{
          for (final section in entity.article.sections)
            for (final citation in section.citations) citation.sourceId,
          for (final citation in entity.citations) citation.sourceId,
        };
        if (cited.isEmpty) continue;
        if (cited.difference(tertiary).isEmpty) {
          problems.add('${entity.ref}: cites only ${cited.join(', ')}');
        }
      }
      // Arguments are held to the same rule. A reconstructed argument that
      // cites only a summary of itself gives a reader no way to check the
      // reconstruction against the text it is reconstructing, which is the one
      // thing a reader of a reconstruction most needs.
      for (final argument in corpus.arguments) {
        final cited = <String>{
          for (final citation in argument.citations) citation.sourceId,
        };
        if (cited.isEmpty) continue;
        if (cited.difference(tertiary).isEmpty) {
          problems.add(
            'argument:${argument.id}: cites only ${cited.join(', ')}',
          );
        }
      }

      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no entry can render as a blank article', () {
      // Every work and every school in the corpus opened with an empty space
      // where the article should be. Their sections are authored at
      // `standard`, the default reading level is `quick`, and `Article.at`
      // faithfully returned nothing — so the screen faithfully drew nothing.
      // Seventy-six entries shipped like that and every test passed, because
      // the content was well formed and the screen was doing as it was told.
      for (final entity in corpus.allEntities) {
        if (entity.article.isEmpty) continue;
        for (final depth in ContentDepth.values) {
          expect(
            entity.article.at(depth),
            isNotEmpty,
            reason: '${entity.ref} shows nothing at ${depth.id}',
          );
        }
      }
    });

    test('no section repeats another section of the same entry', () {
      // A deepening pass added a "standard" section to thirty entries, and
      // three of them restated a section the entry already had — Heidegger's
      // party membership was written twice, in different words, one above the
      // other. Nothing caught it: both sections were well formed, cited, and
      // bilingual. It was found by looking at a screenshot.
      //
      // Word overlap does not separate the cases: a legitimate pair on Rūmī
      // shares more vocabulary than the duplicate did. What does separate them
      // is a long identical run of words — restating a fact tends to reuse the
      // phrasing. Across the whole corpus the longest run between two genuine
      // sections is five words; the duplicate ran to nine.
      const maximumSharedRun = 6;
      final problems = <String>[];

      for (final entity in corpus.allEntities) {
        final sections = entity.article.sections;
        for (var i = 0; i < sections.length; i++) {
          for (var j = i + 1; j < sections.length; j++) {
            final shared = _longestSharedRun(
              sections[i].body.en,
              sections[j].body.en,
              subject: entity.name.en,
            );
            if (shared >= maximumSharedRun) {
              problems.add(
                '${entity.ref}: "${sections[i].id}" and "${sections[j].id}" '
                'share a run of $shared words',
              );
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('every entity has a one-line summary in both languages', () {
      for (final entity in corpus.allEntities) {
        expect(
          entity.oneLine.en.trim(),
          isNotEmpty,
          reason: '${entity.ref} has no English one-line summary',
        );
        expect(
          entity.oneLine.isTranslated,
          isTrue,
          reason:
              '${entity.ref} has no Persian one-line summary. The product is '
              'bilingual by construction; an untranslated entry is incomplete, '
              'not merely unpolished.',
        );
      }
    });

    test('a person is spelled one way everywhere the reader reads', () {
      // The corpus names people with their diacritics — Ibn Sīnā, Nāgārjuna,
      // Gödel, Nezahualcóyotl — and then thirty passages of running prose
      // dropped them. A reader met "Ibn Sīnā" as the title of the entry and
      // "Ibn Sina" in the paragraph under it, and the work "Songs of
      // Nezahualcoyotl" was filed under a philosopher named Nezahualcóyotl.
      // Twenty-six author fields in the bibliography had the same split, so
      // the same scholar appeared twice in a list of sources.
      //
      // Two spellings of one name is not a typographic quibble in a reference
      // work: it is the product disagreeing with itself about who it is
      // talking about, and it makes a search for the name in one spelling miss
      // the passages that use the other.
      //
      // The bare form is deliberate in exactly one place — `alsoKnownAs`,
      // which exists to let a reader who types "Rumi" find Rūmī — so this
      // walks prose and titles and leaves the search aliases alone.
      final canonical = <String, String>{};
      for (final philosopher in corpus.philosophers) {
        final name = philosopher.name.en.replaceAll(RegExp(r'\s*\(.*?\)'), '');
        final bare = _withoutDiacritics(name);
        if (bare != name && bare.length >= 4) canonical[bare] = name;
      }

      final problems = <String>[];
      void check(String where, String? text) {
        if (text == null) return;
        for (final entry in canonical.entries) {
          if (RegExp('(?<![A-Za-z])${RegExp.escape(entry.key)}(?![A-Za-z])')
              .hasMatch(text)) {
            problems.add('$where says "${entry.key}", not "${entry.value}"');
          }
        }
      }

      for (final entity in corpus.allEntities) {
        check('${entity.ref} title', entity.name.en);
        for (final section in entity.article.sections) {
          check('${entity.ref} section "${section.id}"', section.body.en);
          check('${entity.ref} heading "${section.id}"', section.heading?.en);
        }
      }
      for (final term in corpus.glossary) {
        check('glossary ${term.id}', term.shortDefinition.en);
        check('glossary ${term.id}', term.longDefinition?.en);
      }
      for (final quote in corpus.quotes) {
        check('quote ${quote.id}', quote.context?.en);
        check('quote ${quote.id}', quote.attributionNote?.en);
      }
      // The bibliography is read by the reader too. Three names in the rights
      // notes escaped the first pass because this walked only prose, and one
      // source line could say "Dignaga" while the entry it cited said
      // "Dignāga".
      for (final source in corpus.sources) {
        check('source ${source.id}', source.title.en);
        check('source ${source.id}', source.rightsNote?.en);
        for (final author in source.authors) {
          check('source ${source.id} author', author);
        }
      }

      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a title in its own script is spelled one way', () {
      // Ibn Sīnā's al-Ishārāt and Mullā Ṣadrā's Asfār are Arabic books, and
      // the work records showed their titles in Persian letterforms — Persian
      // yeh for Arabic yeh, Persian kaf for Arabic kaf — while the source
      // records for the very same books held the Arabic. One corpus, two
      // spellings of one title, and the wrong one was the one on the screen.
      //
      // The check is about letterforms, not wording. Two records may hold a
      // full title and a short one — al-Rāzī's Mabāḥith is "المباحث المشرقية"
      // in one place and the full "المباحث المشرقية في علم الإلهيات
      // والطبيعيات" in the other, and both are right. What cannot both be
      // right is the same words written with different letters. So the two are
      // compared only once the interchangeable pairs are folded together: if
      // they agree then and differ now, one of them is wrong.
      String folded(String value) => value
          .replaceAll('ی', 'ي')
          .replaceAll('ک', 'ك')
          .replaceAll('ۀ', 'ة')
          .replaceAll('ه‍', 'ة');

      final byEnglishTitle = <String, Source>{
        for (final source in corpus.sources) source.title.en: source,
      };

      for (final work in corpus.works) {
        final original = work.originalTitle;
        final source = byEnglishTitle[work.name.en];
        final arabic = source?.title.forCode('ar');
        if (original == null || arabic == null) continue;
        if (folded(original) != folded(arabic)) continue;
        expect(
          original,
          arabic,
          reason:
              '${work.id} shows "$original" and source ${source!.id} writes '
              'the same words as "$arabic"',
        );
      }
    });

    test('every note about a source is written in both languages', () {
      // A rights note says how to follow the citation, so it is read by the
      // reader and not by the editor. It was a bare English string until it
      // was put on the screen, which would have put English prose on a Persian
      // page — the defect the section rule below exists to prevent, arriving
      // through the bibliography instead.
      for (final source in corpus.sources) {
        final note = source.rightsNote;
        if (note == null) continue;
        expect(
          note.isTranslated,
          isTrue,
          reason: 'source ${source.id} has an untranslated rights note',
        );
      }
    });

    test('every authored section carries text in both languages', () {
      for (final entity in corpus.allEntities) {
        for (final section in entity.article.sections) {
          expect(
            section.body.isTranslated,
            isTrue,
            reason: '${entity.ref} section "${section.id}" has no Persian text',
          );
        }
      }
    });

    test('every non-factual passage cites a source', () {
      for (final entity in corpus.allEntities) {
        expect(
          entity.article.meetsCitationPolicy,
          isTrue,
          reason:
              '${entity.ref} makes an interpretive or contested claim without '
              'citing anything. Marking a claim as interpretation and then not '
              'saying whose interpretation it is helps nobody.',
        );
      }
    });

    test('every quotation satisfies the attribution rules', () {
      for (final quote in corpus.quotes) {
        expect(
          quote.isPublishable,
          isTrue,
          reason:
              'quote:${quote.id} claims "${quote.attribution.id}" without the '
              'support that status requires',
        );
      }
    });

    test('a work and its own edition give the book one Persian name', () {
      // Thirty-six of them gave it two. The Fragility of Goodness was
      // «شکنندگی خیر» as an entry and «شکنندگی نیکی» in the source record the
      // entry cites; Consciencism was «ضمیرگرایی» and «آگاهی‌گرایی»; The World
      // as Will was «بازنمود» in one and «تصور» in the other. A reader who
      // follows a citation lands on a book with a different name.
      //
      // A source may carry the fuller title — a subtitle, a volume number,
      // the original where the entry translates it — so the rule is
      // containment rather than equality.
      // Nine sources give the book a different name on purpose: the entry
      // shows a short display title and the record carries the full one
      // («ایده‌هایی برای پدیدارشناسی ناب، کتاب اول»), or the entry translates
      // the title and the record transliterates it («تنتره‌آلوکه»), or the
      // fragments are filed under the poems they were quoted from.
      const named = <String>{
        'empedocles-fragments',
        'fushikaden',
        'ideas-i',
        'letters-to-lucilius',
        'liberte-negritude',
        'normal-and-pathological',
        'simmun-hwajaeng-non',
        'tantraloka',
        'unsettling-coloniality',
      };
      String fold(String text) => text.replaceAll(RegExp('[«»؟?ٔ‌ ]'), '');
      final problems = <String>[];
      for (final work in corpus.works) {
        for (final sourceId in work.editionSourceIds) {
          if (!sourceId.endsWith(work.id)) continue;
          if (named.contains(work.id)) continue;
          final source = corpus.source(sourceId);
          final title = work.name.fa;
          final edition = source?.title.fa;
          if (title == null || edition == null) continue;
          if (fold(title).contains(fold(edition)) ||
              fold(edition).contains(fold(title))) {
            continue;
          }
          problems.add(
            'work:${work.id} is "$title" and $sourceId is "$edition"',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a name keeps its diacritics in the English too', () {
      // The Persian side has a rule that a philosopher is spelled one way;
      // the English side did not, and eight passages dropped a mark the name
      // is written with: «Sadra» once against «Ṣadrā» thirty-six times,
      // «Cesaire» twice, «Oyewumi», «Mariategui», «Anzaldua», «Ghazali»
      // twice, «Farabi» twice — and «Khayyām» three times where the entry
      // itself writes «Khayyam» with no macron at all.
      //
      // `alsoKnownAs` is exempt: a plain-ASCII spelling listed there is what
      // lets a reader who types «Anzaldua» into search find her.
      const wrong = <String, String>{
        'Sadra': 'Ṣadrā',
        'Cesaire': 'Césaire',
        'Oyewumi': 'Oyěwùmí',
        'Mariategui': 'Mariátegui',
        'Anzaldua': 'Anzaldúa',
        'Ghazali': 'Ghazālī',
        'Farabi': 'Fārābī',
        'Khayyām': 'Khayyam',
      };
      final problems = <String>[];
      for (final entry in englishStrings) {
        for (final pair in wrong.entries) {
          if (RegExp('(?<![A-Za-z])${pair.key}(?![A-Za-z])')
              .hasMatch(entry.text)) {
            problems.add(
              '${entry.file} ${entry.path}: "${pair.key}" — the entry writes '
              '"${pair.value}"',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no quotation is entered twice', () {
      // Four were: Beauvoir's «زن زاده نمی‌شوند» under two ids, Leibniz's
      // windowless monads under two, Mill on Socrates under two, and the
      // apocryphal Hypatia line under two. Each pair carried a different
      // Persian wording of the same sentence — «ناخرسند» in one and
      // «ناخشنود» in the other — so the entry showed the reader the same
      // quotation twice, translated twice.
      final byText = <String, List<String>>{};
      for (final quote in corpus.quotes) {
        for (final text in <String?>[quote.text.en, quote.text.fa]) {
          if (text == null) continue;
          byText.putIfAbsent(text, () => <String>[]).add(quote.id);
        }
      }
      final duplicates = <String>[
        for (final entry in byText.entries)
          if (entry.value.length > 1)
            '${entry.value.join(' and ')} are the same quotation',
      ];

      // Thirteen more pairs were the same quotation in two English wordings,
      // which an exact match cannot see: «two-ness» beside «twoness», «can
      // rightfully» beside «can be rightfully», «problems» beside «social
      // problems». The Persian differed in every pair, and in one of them the
      // two translations disagreed about what the line says — Laozi's chapter
      // 33 was «زیرکی/فرزانگی» in one and «دانایی/روشن‌بینی» in the other.
      //
      // Berkeley's pair is the exception the rule needs: his own «Their esse
      // is percipi» and the plain-English version he is usually reported in
      // are both here on purpose, and the entry for each says so.
      const deliberate = <String>{'berkeley-esse|berkeley-esse-tag'};
      final quotes = corpus.quotes.toList();
      for (var i = 0; i < quotes.length; i++) {
        for (var j = i + 1; j < quotes.length; j++) {
          final a = quotes[i];
          final b = quotes[j];
          if (a.speakerId != b.speakerId) continue;
          if (deliberate.contains('${a.id}|${b.id}')) continue;
          if (_similarity(a.text.en, b.text.en) > 0.62) {
            duplicates.add(
              '${a.id} and ${b.id} are the same quotation, worded twice',
            );
          }
        }
      }
      expect(duplicates, isEmpty, reason: duplicates.join('\n'));
    });

    test('a quotation is filed under the person it is attributed to', () {
      // The Burke line and the Voltaire line — both of them misattributions,
      // and neither man an entry in this corpus — were filed under Mill,
      // which put two quotations on his page that he did not say and that
      // nobody claims he said. A quotation with nowhere honest to sit does
      // not get to sit somewhere else.
      for (final quote in corpus.quotes) {
        final speaker = corpus.philosopher(quote.speakerId);
        expect(
          speaker,
          isNotNull,
          reason: 'quote:${quote.id} names a speaker who is not an entry',
        );
        final note = quote.attributionNote?.en ?? '';
        final surname = speaker!.name.en.split(' ').last;
        if (quote.needsCaveat && note.isNotEmpty) {
          expect(
            note.contains(surname),
            isTrue,
            reason:
                'quote:${quote.id} is filed under ${speaker.name.en} but the '
                'note correcting it never mentions them, which is the shape '
                'of a quotation parked on the wrong entry',
          );
        }
      }
    });

    test('a note that names the work names the work being cited', () {
      // Two quotations named one book and cited another. The Plato line about
      // writing is Phaedrus 275d and its note said so, while the citation
      // pointed at the Phaedo — a different dialogue, so the reader who
      // followed the link landed on the wrong book. Cicero's address to
      // philosophy opens Tusculan Disputations V, which its note also said,
      // and the citation pointed at On the Nature of the Gods.
      //
      // Both notes were right and both citations were wrong, which is the
      // shape this catches: a note that tells the reader where a passage
      // lives, over a citation that sends them elsewhere.
      final named = RegExp(
        r'\bfrom (?:the )?([A-Z][\w’-]*(?:\s+[A-Z][\w’-]*){0,3})(?=[,.;:]|$)',
      );
      // The lookahead keeps the pattern to phrases that end where a title
      // ends. Without it "quoting from Stoic handbooks" reads as a work
      // called Stoic.
      for (final quote in corpus.quotes) {
        final note = quote.attributionNote?.en;
        final citation = quote.citation;
        if (note == null || citation == null) continue;
        final title = corpus.source(citation.sourceId)?.title.en;
        final match = named.firstMatch(note);
        if (title == null || match == null) continue;
        // A person is not a work: "quoting ... rather than from Zeno" names
        // the man, not a book of his, and he has none.
        final phrase = match.group(1)!;
        if (!phrase.contains(' ') &&
            corpus.philosophers.any(
              (p) => p.name.en.split(' ').contains(phrase),
            )) {
          continue;
        }
        expect(
          note.toLowerCase().contains(title.toLowerCase()),
          isTrue,
          reason:
              'quote:${quote.id} cites "$title" but its note says the '
              'passage is from "$phrase"',
        );
      }
    });

    test('verified quotations point at a source that exists', () {
      for (final quote in corpus.quotes.where(
        (q) => q.attribution == AttributionStatus.verified,
      )) {
        final citation = quote.citation;
        expect(citation, isNotNull, reason: 'quote:${quote.id}');
        expect(
          corpus.source(citation!.sourceId),
          isNotNull,
          reason: 'quote:${quote.id} cites missing source ${citation.sourceId}',
        );
      }
    });

    test('quotations that need a caveat are not offered for sharing', () {
      // Sharing a misattributed line is precisely how misattribution spreads,
      // so the two flags must never both be true.
      for (final quote in corpus.quotes) {
        expect(
          quote.needsCaveat && quote.isShareable,
          isFalse,
          reason: 'quote:${quote.id} is both caveated and shareable',
        );
      }
    });

    test('every philosopher rests on a text, not only on the encyclopedia', () {
      // 147 of 191 entries once cited nothing but the Stanford Encyclopedia,
      // because the corpus held no text of theirs. That is one defect wearing
      // two coats: the entry is thin *and* it is unsourced, and an entry whose
      // only support is a tertiary summary is repeating what it read.
      //
      // Two philosophers legitimately have no text — Pythagoras and Hypatia
      // left no writing at all — and they are grounded in the ancient reports
      // that do exist rather than exempted, because a named report is evidence
      // and an encyclopedia entry about it is not.
      final unsupported = <String>[];
      for (final philosopher in corpus.philosophers) {
        final cited = <String>{
          for (final citation in philosopher.citations) citation.sourceId,
          for (final section in philosopher.article.sections)
            for (final citation in section.citations) citation.sourceId,
        };
        final rests = cited
            .map(corpus.source)
            .nonNulls
            .any((source) => source.kind.rank <= SourceKind.monograph.rank);
        if (!rests) unsupported.add(philosopher.id);
      }
      expect(
        unsupported,
        isEmpty,
        reason:
            'these entries cite only reference works: ${unsupported.join(', ')}',
      );
    });

    test('every philosopher offers more than one reading depth', () {
      // The reader can ask for more, and for 127 entries the control had
      // nothing to give: one `quick` paragraph was the whole article, so
      // turning the depth up changed nothing on the screen. A depth control
      // that does not work is worse than none, because it promises.
      final flat = corpus.philosophers
          .where(
            (philosopher) =>
                philosopher.article.sections
                    .map((section) => section.depth)
                    .toSet()
                    .length <
                2,
          )
          .map((philosopher) => philosopher.id)
          .toList();
      expect(
        flat,
        isEmpty,
        reason: 'these entries have only one depth: ${flat.join(', ')}',
      );
    });

    test('no source carries an identifier or page range unless it is real', () {
      // The content policy forbids inventing bibliographic detail. Nothing in
      // the shipped corpus should carry a DOI, ISBN or page range at all yet;
      // when one is added it must come from the physical source in hand. This
      // test is the tripwire for that rule.
      for (final source in corpus.sources) {
        expect(
          source.identifier,
          isNull,
          reason:
              'source:${source.id} has an identifier. If it was checked '
              'against the actual publication, update this test; if it was '
              'reconstructed from memory, remove it.',
        );
        expect(
          source.pages,
          isNull,
          reason: 'source:${source.id} has a page range; see above.',
        );
      }
    });

    test('every cited author has a Persian name', () {
      // Under a Persian article the citation line read «Plato · جمهوری · 507b»
      // — the work translated and the author left in Latin, in the middle of a
      // right-to-left line, in a product whose main audience reads Persian.
      //
      // Most Persian renderings come from the philosopher's own record, so the
      // two cannot drift apart; the rest are editors and canons with no entry
      // of their own. Either way a source with authors must have both forms.
      final bare = <String>[];
      for (final source in corpus.sources) {
        if (source.authors.isEmpty) continue;
        if (source.authorsFa.length != source.authors.length) {
          bare.add(
            'source:${source.id} prints ${source.authors.join(', ')} in '
            'Persian too',
          );
        }
      }
      expect(
        bare,
        isEmpty,
        reason:
            'add the Persian form to assets/content/sources.json:\n  '
            '${bare.join('\n  ')}',
      );
    });

    test('every passage of authored prose names its sources', () {
      // Sourcing used to be uneven in a way a reader would notice: a
      // philosopher's standard section carried its citations and the in-depth
      // layer under it carried none, and most concept, school and work
      // sections carried none at all. The page ended with a reference list, so
      // nothing was strictly unsourced — but there was no way to tell which
      // passage rested on what, which is the part that matters.
      //
      // Quick sections are exempt by design: they are one-sentence summaries
      // of the sections below them, and a reference list under two lines is
      // noise rather than rigour.
      final bare = <String>[];
      for (final entity in corpus.allEntities) {
        for (final section in entity.article.sections) {
          if (section.depth == ContentDepth.quick) continue;
          if (section.citations.isNotEmpty) continue;
          bare.add('${entity.ref}: "${section.id}" (${section.depth.id})');
        }
      }
      expect(
        bare,
        isEmpty,
        reason:
            'these passages show the reader no source:\n  ${bare.join('\n  ')}',
      );
    });

    test('a quotation does not contradict its own attribution', () {
      // Found on screen rather than by any test: the opening couplet of the
      // Masnavī — a line every Persian reader knows — was displayed badged as
      // verified and captioned "corresponds to no located line". The audit
      // that removed a fabricated Rūmī line had put the genuine couplet in its
      // place and left the debunking note behind, so the app was warning
      // readers away from the one quotation on the card that was certainly
      // real.
      //
      // Two rules, both mechanical. `actualSource` names where a line really
      // comes from when it is attributed to the wrong person; on a verified
      // quotation it has nothing to say. And a note that reports failure to
      // trace the line cannot sit under a badge asserting it was traced.
      final untraced = RegExp(
        r'not (been )?(traced|identified|located)|no located|does not appear',
        caseSensitive: false,
      );
      final problems = <String>[];

      for (final quote in corpus.quotes) {
        if (quote.attribution != AttributionStatus.verified) continue;
        if (quote.actualSource != null) {
          problems.add(
            'quote:${quote.id} is verified and still carries an actualSource, '
            'which is the field for a line attributed to the wrong person',
          );
        }
        final note = quote.attributionNote?.en;
        if (note != null && untraced.hasMatch(note)) {
          problems.add(
            'quote:${quote.id} is badged verified and its note says the line '
            'could not be traced: "$note"',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Coverage', () {
    test('no article is a dead end', () {
      // An article with nothing to press leaves a reader at the end of a
      // corridor: back is the only move. Forty-eight philosophers were in
      // that state — no concepts, no works, no school, no relations — and
      // nothing failed, because every one of them was internally valid.
      //
      // Traditions and branches count, since the chips carrying them open
      // Explore filtered to that term. They are also the only route that does
      // not depend on an entry having been given cross-references by hand,
      // which is why every entry is required to carry at least one.
      final stranded = <String>[];
      for (final entity in corpus.allEntities) {
        final ways =
            entity.traditions.length +
            entity.branches.length +
            corpus.relationsFor(entity.ref).length;
        if (ways == 0) stranded.add(entity.ref.toString());
      }
      expect(
        stranded,
        isEmpty,
        reason:
            'these articles offer the reader nowhere to go:\n  '
            '${stranded.join('\n  ')}',
      );
    });

    test('a philosopher listed in a school lists the school back', () {
      // The link is rendered from the philosopher's own record, so a
      // membership recorded only on the school's side is invisible on the
      // page where a reader would look for it.
      final missing = <String>[];
      for (final school in corpus.schools) {
        for (final id in school.memberIds) {
          final philosopher = corpus.philosopher(id);
          if (philosopher == null) continue;
          if (!philosopher.schoolIds.contains(school.id)) {
            missing.add('${philosopher.id} is a member of ${school.id}');
          }
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('the corpus is not confined to one tradition', () {
      // A product claiming to cover world philosophy fails silently if its
      // content drifts back toward the European canon, because nothing breaks.
      final traditions = corpus.philosophers
          .expand((philosopher) => philosopher.traditions)
          .toSet();
      expect(
        traditions.length,
        greaterThanOrEqualTo(6),
        reason: 'philosophers span only $traditions',
      );
    });

    test('philosophers can be ordered chronologically', () {
      final ordered = corpus.philosophersChronologically;
      expect(ordered, isNotEmpty);
      for (var index = 1; index < ordered.length; index++) {
        expect(
          ordered[index].timelineAnchor!.year,
          greaterThanOrEqualTo(ordered[index - 1].timelineAnchor!.year),
          reason: 'timeline ordering is not monotonic',
        );
      }
    });

    test('a book is reachable from the person who wrote it', () {
      // A philosopher used to carry a list of their own works alongside the
      // author field on each work, and nothing ever read it: the page, the
      // quiz and the search all resolve a person's books by asking which
      // works name them as author. Fifty-four entries kept the list and a
      // hundred and thirty-eight did not, which is what a second copy of a
      // fact does when only one copy is load-bearing.
      //
      // The list is gone. What matters is that the one remaining link
      // resolves in both directions, which is what this asks.
      for (final work in corpus.works) {
        final author = corpus.philosopher(work.authorId);
        expect(
          author,
          isNotNull,
          reason: 'work:${work.id} names an author who is not an entry',
        );
        expect(
          corpus.worksBy(author!.id).map((it) => it.id),
          contains(work.id),
          reason:
              'work:${work.id} names ${author.id} as author, and asking the '
              'corpus for their works does not return it',
        );
      }
    });

    test('a book is not written before its author was born', () {
      // The Viṃśatikā was dated c. 350 and Vasubandhu is born c. 400 in his
      // own entry, so the corpus had him writing half a century before he
      // existed. Patañjali carried the grammarian's dates, two centuries
      // BCE, while the Yoga Sūtras article says in as many words that the
      // identification with the grammarian is rejected — so the work he is
      // known for was dated five hundred years after his death. The
      // Investigations were dated 1953, which is when they were published,
      // two years after Wittgenstein died; the field says composed, and the
      // timeline reads "Written 1953".
      //
      // A book finished after its author died is a different matter and
      // ordinary: an anthology gathered by a community, a manuscript
      // published posthumously. Those are named here rather than caught,
      // because each one is explained in the article that carries it.
      const compiledLater = <String>{
        'analects',
        'daodejing',
        'dhammapada',
        'how-it-is-cordova',
      };
      for (final work in corpus.works) {
        final composed = work.composed?.start?.year;
        final author = corpus.philosopher(work.authorId);
        if (composed == null || author == null) continue;
        final born =
            author.life.birth?.year ?? author.life.floruit?.start?.year;
        if (born != null) {
          expect(
            composed,
            greaterThanOrEqualTo(born),
            reason:
                'work:${work.id} is dated $composed and ${author.name.en} is '
                'not there until $born',
          );
        }
        if (compiledLater.contains(work.id)) continue;
        final died = author.life.death?.year ?? author.life.floruit?.end?.year;
        if (died != null) {
          expect(
            composed,
            lessThanOrEqualTo(died),
            reason:
                'work:${work.id} is dated $composed and ${author.name.en} '
                'died in $died',
          );
        }
      }
    });

    test('the numbers the documentation quotes are the numbers here', () {
      // The README said 191 philosophers after a hundred and ninety-second
      // was added, 256 quotations against a file holding 238, and 303 sources
      // against 305. A reference work that miscounts itself on its own front
      // page has said something false before the reader opens it.
      //
      // Only the collection sizes are checked here, because those are the
      // ones that move on every content commit. The prose totals come from
      // tool/corpus_stats.py, which the status page names so a reader can
      // reproduce them.
      final counts = <String, int>{
        'philosophers': corpus.philosophers.length,
        'concepts': corpus.concepts.length,
        'works': corpus.works.length,
        'schools': corpus.schools.length,
        'quotations': corpus.quotes.length,
        'arguments': corpus.arguments.length,
        'sources': corpus.sources.length,
      };

      final readme = File('README.md').readAsStringSync();
      for (final entry in counts.entries) {
        expect(
          readme,
          contains('${entry.value} ${entry.key}'),
          reason:
              'README.md does not say "${entry.value} ${entry.key}"; the '
              'corpus holds ${entry.value}',
        );
      }

      final status = File('docs/STATUS.md').readAsStringSync();
      const rows = <String, String>{
        'Philosophers': 'philosophers',
        'Concepts': 'concepts',
        'Works': 'works',
        'Schools': 'schools',
        'Quotations': 'quotations',
        'Arguments': 'arguments',
        'Sources': 'sources',
      };
      for (final row in rows.entries) {
        expect(
          status,
          contains('| ${row.key} | ${counts[row.value]} |'),
          reason:
              'docs/STATUS.md does not give ${row.key} as ${counts[row.value]}',
        );
      }

      final entities =
          corpus.philosophers.length +
          corpus.concepts.length +
          corpus.works.length +
          corpus.schools.length;
      expect(
        status,
        contains('All $entities philosophers'),
        reason: 'docs/STATUS.md does not give the entity total as $entities',
      );
      expect(
        status,
        contains('${entities * 2} screens'),
        reason:
            'docs/STATUS.md does not give the both-languages screen count as '
            '${entities * 2}',
      );
    });

    test('an argument is credited to the person who made it', () {
      // The Third Man had Plato advancing it and Aristotle opposing it,
      // which is backwards in both directions. It is the argument that
      // Plato's Forms generate an infinite regress of further Forms — the
      // record's own one-line summary says so — and the passage it cites is
      // Aristotle pressing it at Metaphysics 990b17. So Plato's page
      // offered him an argument that concludes his theory is incoherent,
      // and Aristotle's page put "Argued against this" over the argument he
      // named.
      //
      // The rule that catches it: an argument cites the text it lives in, so
      // the author of that text is one of the people advancing it. Zeno is
      // the exception that shapes the rule rather than breaking it — nothing
      // he wrote survives, so Achilles and the tortoise reaches us only
      // through Aristotle reporting it in order to answer it, and the
      // citation has to be to an opponent because there is nowhere else for
      // it to point.
      for (final argument in corpus.arguments) {
        final proponents = argument.proponentIds
            .map(corpus.philosopher)
            .nonNulls;
        if (proponents.isEmpty) continue;
        if (proponents.every((p) => p.writings != Writings.extant)) continue;
        for (final citation in argument.citations) {
          final source = corpus.source(citation.sourceId);
          if (source == null || source.kind != SourceKind.primaryText) continue;
          for (final author in source.authors) {
            final person = corpus.philosophers
                .where(
                  (p) => p.name.en == author || p.alsoKnownAs.contains(author),
                )
                .firstOrNull;
            if (person == null) continue;
            expect(
              argument.opponentIds.contains(person.id),
              isFalse,
              reason:
                  'argument:${argument.id} cites ${source.id}, which '
                  '${person.name.en} wrote, and lists them as opposing it',
            );
          }
        }
      }
    });

    test('a reply is not written before the thing it replies to', () {
      // Shankara was recorded as opposing Rāmānuja. He died in 820 and
      // Rāmānuja was born in 1017, and the note attached to the relation
      // says which way it actually ran: "Rāmānuja's commentary is written
      // explicitly against Shankara's". Two centuries of Vedānta pointed
      // backwards on both men's pages.
      //
      // These four types are the ones where the subject acts on something
      // the object already said, so the subject cannot have finished before
      // the object began. Influence and teaching are left out: they are
      // caught by the ordinary reading of the dates, and a teacher who dies
      // in the student's childhood is a different question.
      const directed = <RelationType>{
        RelationType.criticized,
        RelationType.defended,
        RelationType.opposed,
        RelationType.respondedTo,
      };
      int? start(String id) {
        final life = corpus.philosopher(id)?.life;
        return life?.birth?.year ?? life?.floruit?.start?.year;
      }

      int? end(String id) {
        final life = corpus.philosopher(id)?.life;
        return life?.death?.year ?? life?.floruit?.end?.year;
      }

      for (final relation in corpus.relations) {
        if (!directed.contains(relation.type)) continue;
        if (relation.subject.kind != EntityKind.philosopher ||
            relation.object.kind != EntityKind.philosopher) {
          continue;
        }
        final replierEnd = end(relation.subject.id);
        final repliedStart = start(relation.object.id);
        if (replierEnd == null || repliedStart == null) continue;
        expect(
          replierEnd,
          greaterThanOrEqualTo(repliedStart),
          reason:
              'relation ${relation.subject.id} ${relation.type.id} '
              '${relation.object.id}: the first was gone by $replierEnd and '
              'the second not there until $repliedStart',
        );
      }
    });

    test('a book has one source record, and an entry cites it once', () {
      // The Xunzi had two source records and the Han Feizi had two, with the
      // same title, the same author and the same Persian author on each pair.
      // Both men's own entries listed both of theirs, so each page showed the
      // one book he wrote twice in its list of sources, and the citations
      // underneath his article did the same.
      //
      // Citing a book twice in one section is ordinary when the locators
      // differ — Heraclitus' entry cites two fragments, Hobbes' two parts of
      // Leviathan — so what is barred is the same source at the same place.
      final byBook = <String, List<String>>{};
      for (final source in corpus.sources) {
        final key = <String>[
          source.title.en.toLowerCase().trim(),
          ...source.authors,
        ].join('|');
        byBook.putIfAbsent(key, () => <String>[]).add(source.id);
      }
      for (final entry in byBook.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason:
              'one book, ${entry.value.length} source records: '
              '${entry.value.join(", ")}',
        );
      }

      final repeated = <String>[];
      void look(String owner, List<Citation> citations) {
        final seen = <String>{};
        for (final citation in citations) {
          final key = '${citation.sourceId}|${citation.locator ?? ""}';
          if (!seen.add(key)) {
            repeated.add('$owner cites ${citation.sourceId} twice over');
          }
        }
      }

      for (final entity in corpus.allEntities) {
        look(entity.ref.toString(), entity.citations);
        for (final section in entity.article.sections) {
          look('${entity.ref} ${section.id}', section.citations);
        }
      }
      expect(repeated, isEmpty, reason: repeated.join('\n'));
    });

    test('the graph connects entities in both directions', () {
      // Authored one way, readable both ways: the relation from Socrates to
      // Plato must be visible on Plato's page as well.
      const socrates = EntityRef(EntityKind.philosopher, 'socrates');
      const plato = EntityRef(EntityKind.philosopher, 'plato');

      expect(
        corpus.relationsFor(socrates).any((r) => r.object == plato),
        isTrue,
        reason: 'the authored direction is missing',
      );
      expect(
        corpus.relationsFor(plato).any((r) => r.object == socrates),
        isTrue,
        reason: 'the inverse reading is missing',
      );
      expect(
        corpus
            .relationsFor(plato)
            .firstWhere((r) => r.object == socrates)
            .isInverseReading,
        isTrue,
        reason:
            'the inverse reading is not marked as inverse, so the '
            'interface would label it "influenced" instead of "influenced by"',
      );
    });
  });
}

/// The longest run of consecutive words appearing in both [a] and [b].
///
/// Words only, lowercased, punctuation dropped — the interest is in reused
/// phrasing rather than in exact text.
/// How many consecutive words the two passages have in common.
///
/// [subject] is the name of the entry both passages belong to, and it is
/// collapsed to a single token before comparing. Every section of an article
/// about Fakhr al-Dīn al-Rāzī is entitled to say his name, and a transliterated
/// name is four or five words — so two sections that merely open with it were
/// reported as sharing a six-word run of prose. Only the entry's own name is
/// collapsed: two sections repeating a clause about somebody else is the
/// duplication this exists to catch.
int _longestSharedRun(String a, String b, {String subject = ''}) {
  final first = _words(_collapse(a, subject));
  final second = _words(_collapse(b, subject));
  var longest = 0;
  for (
    var length = 3;
    length <= first.length && length <= second.length;
    length++
  ) {
    final grams = <String>{
      for (var i = 0; i + length <= first.length; i++)
        first.sublist(i, i + length).join(' '),
    };
    var found = false;
    for (var i = 0; i + length <= second.length; i++) {
      if (grams.contains(second.sublist(i, i + length).join(' '))) {
        found = true;
        break;
      }
    }
    if (!found) break;
    longest = length;
  }
  return longest;
}

/// The words of an English passage.
///
/// Any Unicode letter, not `[A-Za-z]`. The ASCII class looked right until the
/// corpus started spelling names with the diacritics they are owed: it cut
/// "Sīnā" into "s" and "n" and "Rāzī" into "r" and "z", so a phrase naming
/// Fakhr al-Dīn al-Rāzī counted as eight tokens instead of four, and the
/// repeated-prose check read a shared name as a shared sentence.
List<String> _words(String text) => RegExp(
  r'\p{L}+',
  unicode: true,
).allMatches(text).map((match) => match.group(0)!.toLowerCase()).toList();

/// Strips combining marks, so "Ibn Sīnā" and "Ibn Sina" can be compared.
String _withoutDiacritics(String value) {
  const marks = <String, String>{
    'ā': 'a',
    'ī': 'i',
    'ū': 'u',
    'ṭ': 't',
    'ṣ': 's',
    'ḍ': 'd',
    'ẓ': 'z',
    'ḥ': 'h',
    'ʿ': '',
    'ʾ': '',
    'ñ': 'n',
    'ṅ': 'n',
    'ṇ': 'n',
    'ś': 's',
    'ö': 'o',
    'ü': 'u',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ó': 'o',
    'á': 'a',
    'í': 'i',
    'ú': 'u',
    'ç': 'c',
    'å': 'a',
    'ř': 'r',
    'ẹ': 'e',
    'ầ': 'a',
    'â': 'a',
    'ô': 'o',
    'ơ': 'o',
    'ư': 'u',
    'ă': 'a',
    'ĩ': 'i',
    'ế': 'e',
    'ộ': 'o',
    'ạ': 'a',
    'ậ': 'a',
    'ằ': 'a',
    'ề': 'e',
    'ọ': 'o',
    'ǎ': 'a',
    'ě': 'e',
    'ǐ': 'i',
    'ǒ': 'o',
    'ǔ': 'u',
    'ō': 'o',
  };
  var result = value;
  marks.forEach((mark, plain) {
    result = result
        .replaceAll(mark, plain)
        .replaceAll(mark.toUpperCase(), plain.toUpperCase());
  });
  return result;
}

/// Replaces [subject] and its bare surname with one token.
String _collapse(String text, String subject) {
  if (subject.isEmpty) return text;
  final name = subject.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  if (name.isEmpty) return text;
  return text.replaceAll(name, 'SUBJECT');
}

/// How alike two strings are, from 0 to 1, by the longest run they share.
///
/// Enough to catch a quotation entered twice in two wordings, which is what it
/// is for; not a general similarity measure.
double _similarity(String a, String b) {
  final left = a.toLowerCase();
  final right = b.toLowerCase();
  if (left.isEmpty || right.isEmpty) return 0;
  final shared = _longestCommonSubsequence(left, right);
  return 2 * shared / (left.length + right.length);
}

int _longestCommonSubsequence(String a, String b) {
  var previous = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      current[j] = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
          ? previous[j - 1] + 1
          : (previous[j] > current[j - 1] ? previous[j] : current[j - 1]);
    }
    previous = current;
  }
  return previous[b.length];
}
