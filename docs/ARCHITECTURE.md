# Architecture

## Layers

```
features/   Screens and widgets. Depends on everything below.
app/        Providers, router, settings. Wires features to data.
core/       Design system, search, formatting, errors. No domain knowledge
            beyond value objects it formats.
data/       Content loading, parsing, the in-memory knowledge base.
domain/     Entities and value objects. Depends on nothing — not even Flutter.
```

The rule that matters: `domain/` imports no Flutter. That is what lets the
entities, the date arithmetic and the article-depth logic be tested as plain
Dart, and it is the first thing to check when adding to it.

## Decision records

Each records what was decided, what else was considered, and what it costs.

---

### ADR 1 — Flutter, targeting mobile first

**Context.** The brief describes a reading and learning product for a general
audience, with an explicit Flutter/Dart reference in its audit checklist.

**Decision.** Flutter 3.47 / Dart 3.13, with web as the build target used for
verification in CI.

**Alternatives.** A web app in React would iterate faster and publish more
easily. Native per-platform would give the best reading experience on each.

**Cost.** Flutter's text rendering for Persian required bundling a font (see
ADR 6) and a language-dependent type scale (ADR 7); neither would have been
needed on the web, where the system fonts handle it.

---

### ADR 2 — The whole corpus loads into memory

**Context.** The content is authored JSON that ships inside the app.

**Decision.** `KnowledgeBase` holds the entire corpus in memory, built once at
startup. Every query above the data layer is a synchronous function call.

**Alternatives.** SQLite with FTS5 would scale further and give full-text search
for free. Lazy per-entity loading would cut startup cost.

**Why.** The corpus is small and will stay small for a long time. Loading it
whole removes per-screen loading states from essentially the entire product,
which is a large and permanent simplification of every screen. It also makes the
app fully usable offline from first launch, with no empty state waiting on a
network call.

**Cost.** This does not scale indefinitely. The threshold is when load time
becomes perceptible on a low-end phone. `KnowledgeRepository` exists precisely
so that crossing it replaces one class rather than rewriting the app.

---

### ADR 3 — Content integrity is checked at load, not trusted

**Context.** Content is hand-authored across eight files that reference each
other by identifier. A rename in one file silently breaks links in another.

**Decision.** `KnowledgeBase.findIntegrityViolations()` checks every
cross-reference in the corpus. It runs at app startup and is asserted empty by
`content_integrity_test.dart`. It returns all violations rather than the first,
so one run gives an editor the whole list.

**Cost.** A startup cost proportional to corpus size, and a check that has to be
extended whenever a new reference field is added. Both are small next to a
reference work that quietly accumulates dead links.

---

### ADR 4 — Exceptions, not a `Result` type

**Context.** Content parsing and loading can fail.

**Decision.** The data layer throws typed exceptions (`ContentException`,
`ContentIntegrityException`). Riverpod's `AsyncValue` carries them to the UI.

**Alternatives.** A `Result<T, E>` type threaded through every call.

**Why.** `AsyncValue` already models loading, data and error, and the UI already
has to handle all three. Adding a second error-carrying abstraction underneath
would mean converting between them at every boundary for no gain. Content
failures are also developer-facing bugs rather than expected conditions —
nothing a reader does can cause one.

**Cost.** Failure modes are not visible in function signatures. Mitigated by the
exceptions being few, documented, and confined to the loading path.

---

### ADR 5 — Hand-written search rather than a package

**Context.** Readers must find one philosopher whether they type `Avicenna`,
`Ibn Sīnā`, `ابن‌سینا` or `ابن سينا` — the last two differing by keyboard, in
code points that are not equal.

**Decision.** A hand-written inverted index (`SearchIndex`) over a hand-written
normaliser (`TextNormalizer`) that folds Persian/Arabic letter variants, strips
diacritics in three scripts, unifies digits, and handles the zero-width
non-joiner.

**Alternatives.** A full-text search package, or SQLite FTS5.

**Why.** The data structure is the easy part. The requirement is the folding, and
no generic package does Persian orthographic normalisation or indexes an
entity's names across scripts and transliterations. That behaviour *is* the
feature.

**Cost.** Prefix and fuzzy matching scan the token list, which is linear in
vocabulary size. Fine at this corpus size; it will need a trie before it is
large. `SearchIndex` exposes size diagnostics so that the point where it stops
being fine is measurable rather than guessed.

---

### ADR 6 — Fonts are bundled rather than assumed

**Context.** Flutter's default font has no Arabic-script coverage. The Persian
half of the product renders as fallback or tofu without a bundled face.

**Decision.** Bundle Vazirmatn for Persian and Spectral for English reading
text, both SIL OFL 1.1. Interface chrome in English is set in the platform sans,
named explicitly (see ADR 13 for the third face, and for why a `null` family is
not the same as "the default").

**Cost.** About 2.1 MB of assets, and an obligation to ship the licences — met by
registering all three with `LicenseRegistry` so they appear in the About screen.

---

### ADR 7 — The type scale depends on the language

**Context.** Persian and Latin script differ in vertical proportion. A scale
tuned on English produces cramped, optically undersized Persian.

**Decision.** `AppTypography.forLanguage` builds the whole text theme from the
active language, applying a size multiplier and extra leading to Persian, and
forcing letter-spacing to zero in Persian — where it breaks the cursive joins
between letters. Quotations are italic in English and upright in Persian, which
has no italic.

**Cost.** The theme is rebuilt when the language changes. Cheap, and it happens
rarely.

---

### ADR 8 — Colours are asserted, not eyeballed

**Context.** A palette is accessible on the day it is designed and stops being so
the first time somebody nudges a value to improve a screenshot.

**Decision.** WCAG 2.1 contrast maths is implemented in `Contrast`, and
`contrast_test.dart` asserts every foreground/background pair in both schemes
against AA — and against AAA for the two colours a reader looks at for minutes at
a time. The test also asserts that neither theme uses pure black or pure white
as a reading surface, so "fixing" contrast by reaching for `#FFFFFF` fails
loudly.

---

### ADR 9 — One article screen for four entity kinds

**Context.** Philosophers, concepts, works and schools all need a title, a
summary, prose at a chosen depth, connections outward, and sources.

**Decision.** One `EntityScreen`, with kind-specific sections selected by a
switch on the entity type.

**Alternatives.** Four screens.

**Why.** Four screens drift apart. The differences between these kinds are a few
sections, not a different reading experience, and one screen makes them
structurally incapable of diverging.

**Cost.** The switch grows as kinds are added. Preferable to four files that
must be kept in agreement by memory.

---

### ADR 10 — Routes are derived from the entity kind

**Context.** `EntityRef.route` generates a path; the router must accept it. A
mismatch is invisible until a reader taps a link and lands nowhere.

**Decision.** `EntityKind` owns its `routeSegment`, `EntityRef.route` derives
paths from it, and `AppRouter` builds its routes by iterating the same enum. The
two cannot disagree.

**Cost.** Entity kinds without an article screen must be listed as exclusions
explicitly, which is the point — adding a kind forces the decision.

---

---

### ADR 11 — Motion is a primitive, not a per-screen decision

**Context.** Animation added screen by screen drifts in duration and easing, and
reduced-motion handling gets forgotten on exactly the screen that needed it.

**Decision.** `core/design/motion.dart` owns the vocabulary: `EntranceAnimation`,
`PressableSurface`, `SmoothSwitcher`, and the page-transition builders. Every one
collapses to nothing when the platform reports reduced motion, and
`motion_test.dart` asserts that for each — and asserts they still animate when it
does not, so "fixing" it by disabling everything fails too.

**Notes.** Two implementation details are load-bearing. The stagger is expressed
as an `Interval` inside one controller rather than a delayed timer, so it is
deterministic and settles in tests. And `PressableSurface` uses a raw `Listener`
rather than a `GestureDetector`: a second tap recogniser around the `InkWell`
joins the same gesture arena, which does not resolve until the pointer lifts, so
the press response appeared only as the press *ended*.

**Cost.** Scroll lists must opt out past the first screenful, since items
disposed off-screen would re-animate on the way back.

---

### ADR 12 — The transition builders live in the design layer, the pages in the router

**Context.** `CustomTransitionPage` is a go_router type.

**Decision.** `core/design` exposes plain Flutter transition builders; `app/router`
wraps them in router pages. The design layer has no dependency on the routing
package.

---

### ADR 13 — A bundled font per script, chained by fallback

**Context.** The product sets Greek names inside English sentences and Arabic
names inside both languages. No bundled face covers Latin, Arabic and polytonic
Greek. Spectral covers the modern Greek block but not Greek Extended, so
`Ἐπίκτητος` and `Ἀριστοτέλης` rendered as empty boxes — and every Arabic-script
name rendered as boxes whenever the interface was in English.

**Decision.** Three faces are bundled — Spectral (Latin), Vazirmatn (Arabic
script), GFS Didot (polytonic Greek) — and every text style declares an explicit
`fontFamilyFallback` chain. `typography_test.dart` asserts that *every* style in
both languages has one, so a new style cannot be added without it.

**Alternatives.** Storing monotonic Greek instead of polytonic would have fitted
the font by degrading the content, which is the wrong way round.

**Cost.** About 190 KB more in the bundle, and a third licence to register.

---

### ADR 14 — The reading surface is flat; the front of house is not

**Context.** The identity is "ink and lamplight", and a lamp implies a source.

**Decision.** Home, Explore and Search paint a `LamplightBackdrop` — two very low
opacity gradients, warm from above and cool from below, no blur. The article
screen does not: it uses the flat `readingSurface` token, because under long-form
text decoration is noise. The backdrop sits behind content rather than under
text, so it does not disturb the contrast ratios the palette is asserted against.

**Cost.** Screens using it must set a transparent scaffold background, which is
easy to forget on a new screen.

---

## Testing strategy

| Level | What it covers |
| --- | --- |
| Pure unit | Date arithmetic, text normalisation, contrast maths, article depth |
| Content | The real shipped corpus: parsing, integrity, editorial policy |
| Search | The real corpus, queried the way readers actually type |
| Widget/smoke | The real app booting, navigating, in both languages and themes |

Content and search tests deliberately run against the corpus that ships rather
than fixtures. A fixture proves the algorithm works on data chosen to make it
work; what matters is whether a reader typing a real name finds the right entry.

## Known architectural gaps

Stated so they are not mistaken for oversights:

- **No persistence beyond preferences.** Bookmarks, notes, highlights and
  reading progress have no storage layer yet. This is the largest missing piece
  and the next one to build.
- **No content versioning.** The corpus is versioned only by git.
- **`SearchIndex` rebuilds wholesale** if the corpus is ever invalidated. Fine
  now; wrong once content can be updated at runtime.
- **No observability.** No error reporting, logging or metrics.
