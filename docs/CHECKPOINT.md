# Project checkpoint

**Date:** 2026-08-13
**Session:** 1 (foundation)
**Branch:** `claude/philosophy-super-app-gzaw5t`

## Starting state, verified

The repository was **empty** — no commits on any branch, nothing on the remote.
Everything below was built in this session. There was no previous state to
reconcile against.

## Environment

| | |
| --- | --- |
| Flutter | 3.47.0 stable (released 2026-08-11) |
| Dart | 3.13.0 |
| Toolchain | Downloaded and installed during this session; not preinstalled |

## Status of the work

Using the status vocabulary strictly.

### PRODUCTION READY (built, tested, and verified by execution)

| Item | Evidence |
| --- | --- |
| Design system: tokens, two themes, language-aware typography | `flutter analyze` clean; rendered in smoke tests |
| WCAG AA/AAA colour compliance | 11 assertions in `contrast_test.dart`, executed and passing |
| Text normalisation across Persian/Arabic, Latin, Greek | 22 assertions in `text_normalizer_test.dart`, executed and passing |
| Search engine | 26 assertions in `search_index_test.dart` against the real corpus, executed and passing |
| Content pipeline: parsing, validation, integrity checking | 15 assertions in `content_integrity_test.dart` against the shipped corpus, executed and passing |
| Bilingual rendering, RTL/LTR, both themes | 13 assertions in `app_smoke_test.dart`, executed and passing |
| Release build | `flutter build web --release` succeeded |

**Totals: 87 tests, all passing. `flutter analyze --fatal-infos
--fatal-warnings` reports no issues. `dart format` reports no changes.**

### IMPLEMENTED AND INTEGRATED (built and rendering, not yet exercised deeply)

- Home screen: daily quotation, tradition-spread starting points, "surprise me"
- Explore screen: chronological philosopher list with tradition filter
- Search screen: live results, zero-result and invitation states
- Article screen: works for all four entity kinds, with depth selector,
  claim marking, citations and graph connections
- Settings: language, theme, reading level, licences
- Settings persistence via `SharedPreferences`

These render correctly and are covered by smoke tests, but have not been
reviewed screen-by-screen against every state in the brief's screen inventory.

### NOT STARTED

Named plainly, because the brief describes far more than one session builds:

- **Reader** — no long-form reading view, no font/width controls, no table of
  contents, no footnotes, no reading position
- **Personal knowledge** — no bookmarks, notes, highlights or collections, and
  **no persistence layer for them**. This is the largest architectural gap.
- **Learning platform** — no lessons, learning paths, adaptive difficulty,
  spaced repetition, quizzes or flashcards
- **Knowledge graph view** — relations are modelled, indexed and displayed as a
  list; there is no visual graph
- **Timeline view** — chronological ordering exists in the data layer and is
  tested; no timeline screen
- **Comparison and debate engines** — not modelled
- **Thought-experiment lab, Socratic mode, daily experience beyond the quote**
- **AI assistant** — nothing
- **CMS, editorial pipeline, content versioning**
- **Sync, backup, observability, analytics, feature flags**
- **Onboarding**
- **Offline** — the app is offline-capable because content is bundled, but this
  was a consequence of ADR 2 rather than a designed offline feature

### KNOWN ISSUES AND LIMITATIONS

1. **Corpus is small.** 14 philosophers, 12 concepts, 14 works, 6 schools, 10
   quotations, 2 arguments, 24 sources, 16 relations. Enough to prove the
   pipeline, nowhere near a reference work.
2. **Article depth is partly hollow.** Most entries have `quick` and `standard`
   text; few have `deep`, none have `research`. The depth selector correctly
   hides levels that have no content, so this degrades honestly rather than
   showing empty screens — but the depth feature is under-fed.
3. **Citations are work-level, not page-level.** By policy: page numbers would
   have to be invented, and inventing them is forbidden. Canonical locators
   (Stephanus, Bekker, A/B) are used where they apply.
4. **Search prefix and fuzzy matching scan the full token list.** Linear in
   vocabulary. Correct and fast at this size; needs a trie before the corpus is
   large.
5. **No runtime verification on a physical device or emulator.** Verified via
   the widget-test harness and a release web build only. No screenshots were
   taken, and no device or browser has run the app.
6. **CI has never executed.** The workflow is written and its individual steps
   were each run locally and pass, but GitHub Actions has not run it.
7. **Generated localisations are gitignored,** so `flutter gen-l10n` must run
   before `flutter analyze` on a fresh clone. CI does this; a human reading only
   the README might not, which is why the README says so.

## What was deliberately not done

- **No fabricated bibliographic detail.** No DOIs, ISBNs, page numbers or
  per-entry URLs appear anywhere, because they could not be checked. A test
  enforces this.
- **No claimed features.** Nothing in the UI advertises a capability that does
  not exist.

## Next exact action

Build the persistence layer for reader-owned data — bookmarks, highlights,
notes, reading position — as one vertical slice:

1. Domain: `Bookmark`, `Highlight`, `Note`, `ReadingPosition` entities keyed by
   `EntityRef` plus a section anchor.
2. Data: a `UserDataRepository` interface with a local implementation. Evaluate
   `sqflite` versus `drift` against ADR 21's dependency criteria; the deciding
   factor is migration support, since this data is the reader's own and losing
   it is unacceptable.
3. Migrations from version 1, with a test that migrates a populated v1 database
   forward and asserts nothing is lost.
4. Providers and UI: a bookmark control on the article screen and a saved-items
   screen.
5. Tests at every layer, including one that changes the app language and asserts
   saved data survives — the brief calls for this explicitly and it is exactly
   the kind of thing that breaks silently.

This must come before the reader and the learning platform, because both of them
need somewhere to store what the reader does.
