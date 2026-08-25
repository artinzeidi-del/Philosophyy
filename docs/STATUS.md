# Project status

Every number below was produced by running against the files in this
repository, not recalled.

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze --fatal-infos` | no issues |
| `flutter test` | 960 passing, across 57 test files |
| `flutter build web --release --no-web-resources-cdn` | succeeds |
| Release build in Chromium: 92 routes × 2 languages | 184 screens, no console errors, no overflows |
| Every entry drawn in both languages | 934 screens, no exception |

## Corpus

| Collection | Entries |
| --- | --- |
| Philosophers | 191 |
| Concepts | 61 |
| Works | 186 |
| Schools | 29 |
| Quotations | 250 |
| Arguments | 12 |
| Sources | 303 |
| Glossary terms | 76 |
| Primer steps | 9 |

All 467 philosophers, concepts, works and schools carry three reading
depths — quick, standard and in depth — in English and Persian, across 1,405
authored sections. Total prose: about 218,000 English words and 237,000
Persian words, which is roughly 16.5 hours of English reading and 24.5 hours
of Persian.

## Editorial guarantees, enforced by tests

- No entity can render as a blank article, and no section may repeat another
  section of the same entry.
- Every entity has a one-line summary and every authored section has text in
  both languages.
- Every passage of authored prose above the quick layer names its sources, and
  every cited source exists.
- No source carries a DOI, ISBN, page range or year unless it is real.
- Every quotation satisfies the attribution rules, and one whose attribution is
  disputed cannot be offered for sharing.
- Every philosopher rests on a primary text, not only on an encyclopedia entry.
- Persian prose is checked for Arabic letterforms, Arabic-Indic digits,
  misplaced zero-width non-joiners and words written half in one script and
  half in another.
- Every character the corpus can print has a glyph in a bundled font.
- A person is spelled one way everywhere the reader reads: prose, headings,
  titles, glossary definitions, quotation notes and the bibliography alike.
- A title in its own script is written the same way wherever it appears, so no
  Arabic book is shown in Persian letterforms.
- Every note explaining how a source is cited exists in both languages.
- Every idea, school and work leads somewhere: the philosophers, works and
  oppositions recorded against an entry are all rendered, not merely stored.

See [`CONTENT_POLICY.md`](CONTENT_POLICY.md) for the rules these tests enforce.

## Built

- Design system with light and dark themes, WCAG AA verified by test
- Motion system that honours the platform's reduced-motion setting
- Three-script typography: Latin, Arabic and polytonic Greek, with fallbacks
- Bilingual architecture throughout, including full right-to-left layout
- Search: cross-script, fuzzy, Persian-aware, with a glossary fallback
- Home, Explore, Search, Glossary, Primer, Quiz, Library, Settings and article
  screens
- A quiz built from the corpus, asking only about entries the reader has marked
  as read, with nine ranks of progress
- Reader's library: saves, notes and highlights, persisted across restarts

## Not built

- A continuous reader, as opposed to article pages
- Spaced review, as opposed to the quiz's single pass
- The relation graph as a visual surface
- Reading history, and therefore any "continue reading" affordance
- An Android release build has not yet been produced or run on a device

## Known limitations

- The web build uses hash URLs (`/#/philosophers/plato`). Clean paths would
  need `usePathUrlStrategy()` plus a server that falls back to `index.html`.
- Coverage is deliberately global but not uniform: some traditions have more
  entries than others, and the gaps are in the less-documented ones.
- A quarter of the section-level citations carry a locator; the rest name the
  text without pointing at the passage. Locators are only added where the
  passage has actually been identified, never inferred to make the apparatus
  look complete.
