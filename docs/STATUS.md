# Project status

Every number below was produced by running against the files in this
repository, not recalled.

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze --fatal-infos` | no issues |
| `flutter test` | 553 passing |
| `flutter build web --release --no-web-resources-cdn` | succeeds |
| Release build in Chromium: 2 languages × 2 themes × 4 viewports × 11 routes | 176 frames, no console errors, no blank frames |

## Corpus

| Collection | Entries |
| --- | --- |
| Philosophers | 191 |
| Concepts | 61 |
| Works | 47 |
| Schools | 29 |
| Quotations | 124 |
| Arguments | 12 |
| Sources | 303 |
| Glossary terms | 76 |
| Primer steps | 9 |

All 328 philosophers, concepts, works and schools carry three reading
depths — quick, standard and in depth — in English and Persian, across 988
authored sections. Total prose: about 165,000 English words and 159,000
Persian words, which is roughly 12.5 hours of English reading and 16.5 hours
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

See [`CONTENT_POLICY.md`](CONTENT_POLICY.md) for the rules these tests enforce.

## Built

- Design system with light and dark themes, WCAG AA verified by test
- Motion system that honours the platform's reduced-motion setting
- Three-script typography: Latin, Arabic and polytonic Greek, with fallbacks
- Bilingual architecture throughout, including full right-to-left layout
- Search: cross-script, fuzzy, Persian-aware, with a glossary fallback
- Home, Explore, Search, Glossary, Primer, Library, Settings and article screens
- Reader's library: saves, notes and highlights, persisted across restarts

## Not built

- A continuous reader, as opposed to article pages
- Learning tools: quizzes, spaced review, progress
- The relation graph as a visual surface
- Reading history, and therefore any "continue reading" affordance
- An Android release build has not yet been produced or run on a device

## Known limitations

- The web build uses hash URLs (`/#/philosophers/plato`). Clean paths would
  need `usePathUrlStrategy()` plus a server that falls back to `index.html`.
- Coverage is deliberately global but not uniform: some traditions have more
  entries than others, and the gaps are in the less-documented ones.
