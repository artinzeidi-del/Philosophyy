# Project checkpoint

**Date:** 2026-08-13
**Session:** 3 (personal knowledge — the reader's own work)
**Branch:** `claude/philosophy-super-app-gzaw5t`

## Starting state, verified

**Session 1** began with an empty repository — no commits on any branch, nothing
on the remote — and built the foundation.

**Session 2** began from commit `e249be2`: analysis clean, 87 tests passing, the
web build running. It reviewed the whole project, fixed the defects listed below,
and built the motion and visual-identity work.

**Session 3** began from commit `48ef05b`: analysis clean, 122 tests passing. It
built the persistence layer — the gap the previous checkpoint named as the
largest — and the library, bookmarking and note-taking on top of it. Nothing was
taken on trust from the previous session's report; the state above was
re-verified by running it.

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
| **Runtime execution** | Release build served and loaded in Chromium 1194 via Playwright, in English and Persian, light and dark, on home and article screens. **Zero JavaScript errors.** Screenshots in `docs/screenshots/`. |
| Motion system, reduced-motion compliance | 14 assertions in `motion_test.dart`, executed and passing |
| Typography: script coverage and Persian scale | 12 assertions in `typography_test.dart`, executed and passing |
| Route coverage: no entity is unreachable | 8 assertions in `router_test.dart`, executed and passing |
| Persistence: bookmarks, notes, highlights, reading position | 32 assertions in `user_data_test.dart`, executed and passing |
| Saving and note-taking through the real interface | 10 assertions in `library_flow_test.dart`, executed and passing |

**Totals: 164 tests, all passing. `flutter analyze --fatal-infos
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

- **Reader** — no dedicated long-form reading view, no font-size or width
  controls, no table of contents, no footnotes. Reading *position* is now saved
  and restored, but the reading surface itself is still the article screen.
- **Highlighting** — the domain model, storage, re-anchoring logic and tests all
  exist, but there is no way for a reader to select text and create one. This is
  the largest gap between what is built and what is reachable.
- **Collections and tags** — not started.
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
5. **No runtime verification on a physical device or emulator.** The app has been
   run for real, but only as a web build in headless Chromium. No Android or iOS
   device or emulator has run it, and neither platform's build has been
   attempted — so platform-specific problems (font rendering on iOS, Android
   back-gesture handling, safe areas on notched devices) are entirely unverified.
6. **The web build must be built with `--no-web-resources-cdn`** to run in a
   network-restricted environment. Flutter otherwise fetches CanvasKit from a
   Google CDN at runtime and renders a blank page if that is blocked. This was
   found by running the app, not by reasoning about it.
7. **CI has never executed.** The workflow is written and its individual steps
   were each run locally and pass, but GitHub Actions has not run it.
8. **Generated localisations are gitignored,** so `flutter gen-l10n` must run
   before `flutter analyze` on a fresh clone. CI does this; a human reading only
   the README might not, which is why the README says so.

## Defects found by running the app, and fixed

None of these were visible to analysis or to the test suite. All were found by
looking at rendered pixels, or by reviewing the code against what its own
comments claimed.

### Session 3

1. **The note composer crashed on every save.** The `TextEditingController` was
   disposed as soon as the bottom sheet returned, but the sheet is still running
   its closing animation and the `TextField` rebuilds at least once more —
   "A TextEditingController was used after being disposed". Found by a widget
   test driving the real composer; it would have thrown for every reader who
   wrote a note. The sheet now owns its controller.
2. **The library screen sorted application state during build.**
   `library.notes..sort()` mutates the list held in the provider, from inside a
   `build`. Copied before sorting.

### Session 2

1. **Polytonic Greek rendered as empty boxes.** Spectral covers the modern Greek
   block but not Greek Extended, so `Ἐπίκτητος` and `Ἀριστοτέλης` lost their
   initial letters. The same gap meant every Arabic-script name rendered as boxes
   whenever the interface language was English. Fixed by bundling a Greek face
   and giving every text style an explicit fallback chain (ADR 13), now asserted
   by `typography_test.dart`.
2. **The card press animation never appeared.** `PressableSurface` wrapped a
   `GestureDetector` around an `InkWell`; both register tap recognisers in the
   same gesture arena, and the arena does not resolve until the pointer lifts —
   so the press response ran as the press *ended*. Replaced with a raw
   `Listener`, which never competes.
3. **The ink ripple was painted behind the card.** A `Material` draws ink beneath
   its child, and the card supplied an opaque background as that child. The
   background is now passed to `PressableSurface` and painted outside the
   `Material`.
4. **The decorative quotation mark was clipped** into an unreadable smudge at the
   card's corner. Repositioned to sit fully inside.
5. **Dead code and unbacked claims.** `MotionTokens.respecting` duplicated
   `Motion.duration`; a `LocalizedText` display extension was unused; the
   not-found screen took a path argument it never rendered. Two comments claimed
   tests that did not exist — the router's `articleKinds` and the search index's
   diagnostics. The dead code is gone and both tests are now written.

### Session 1

6. **Interface chrome was rendering in the content serif.** `chromeFamily`
   returned `null` for English, intending "use the platform sans"; a `TextStyle`
   with no family instead inherits one from the ambient `DefaultTextStyle`,
   which inside a `Material` is the serif. The whole interface was set in
   Spectral, losing the distinction between reading and operating the app. Fixed
   by naming the sans explicitly.
7. **The "show all" filter chip was labelled "Explore"**, reusing the navigation
   string. Among a row of tradition names it meant nothing. Given its own
   string in both languages.

## What was deliberately not done

- **No fabricated bibliographic detail.** No DOIs, ISBNs, page numbers or
  per-entry URLs appear anywhere, because they could not be checked. A test
  enforces this.
- **No claimed features.** Nothing in the UI advertises a capability that does
  not exist.

## Next exact action

Build the **reading experience** on top of the persistence that now exists:

1. A dedicated reader view for long-form article text, with the reader's own
   controls over size and measure — the design tokens (`Breakpoints.readingMeasure`,
   `AppTypography.reading(scale:)`) already anticipate this and are unused.
2. Text selection that creates a `Highlight`. Everything behind it is built and
   tested — including re-anchoring when the corpus is edited — and none of it is
   reachable from the interface, which is the most wasteful state for code to be
   in.
3. A table of contents from `Article.sections`, and footnote/citation links that
   scroll rather than navigate away.

After that, the honest priority order is: content depth (the corpus is still
small and most entries stop at `standard`), then the learning platform, then the
knowledge-graph view.
