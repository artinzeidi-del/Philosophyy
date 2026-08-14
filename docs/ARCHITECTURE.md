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

---

### ADR 15 — The reader's library is a versioned JSON document, not a database

**Context.** Bookmarks, notes, highlights and reading positions are the only
data in the product that cannot be regenerated: the corpus ships in the binary,
a note does not.

**Decision.** The whole library is one JSON document with an explicit schema
version, written through a `KeyValueStore` abstraction backed by
`SharedPreferences`. Loading and saving are whole-document operations.

**Alternatives.** `drift` or `sqflite` would give real queries and per-row
writes. Both were rejected for now: a reader's annotations are kilobytes, and
`drift` on web needs a WASM SQLite build and a worker script — a large amount of
machinery for data that fits comfortably in a string.

**Why the version matters more than the storage engine.** A document from an
older schema is migrated one step at a time; a document from a *newer* schema is
refused outright rather than parsed hopefully, because reading a reader's notes
wrongly and then saving the damage back is worse than not reading them at all.

**When to change this.** When the library outgrows a single document — thousands
of notes, or full-text search across them — or when notes need to sync between
devices, at which point per-item identity and modification times start to matter
more than simplicity. `UserDataRepository` exists so that this is a change of
implementation rather than a change of app.

**Cost.** Every save rewrites the whole document. Irrelevant at kilobytes;
disqualifying at megabytes.

---

### ADR 16 — Unreadable saved data is set aside, never overwritten

**Context.** If the stored library cannot be parsed, the app has two bad
options: refuse to start, or start empty and overwrite the reader's work on the
next save.

**Decision.** Neither. The unreadable document is moved to a salvage key, the
reader gets an empty library and a working app, and their original bytes stay on
the device for a recovery path to reach. `clear()` removes the salvage copy too,
so deleting your data really deletes it.

**Cost.** A key that usually holds nothing, and a recovery path that does not yet
exist — the bytes are kept but there is currently no interface for restoring
them.

---

### ADR 17 — Traditions and branches are content, not enums

**Context.** Traditions and branches were two Dart enums — sixteen and eighteen
values, switched over exhaustively for their bilingual labels. This made a typo
a compile error, which is genuinely valuable. It also meant that Korean,
Vietnamese, Tibetan, Ethiopian, Mesoamerican, Andean and every Indigenous
tradition could not be *named* by the product without a Dart change and a
release. A reference work whose vocabulary of world traditions is fixed in its
binary has decided in advance which philosophies exist.

There is a second, quieter failure a fixed branch list produces. A branch list
drawn from the Western division of philosophy asks every other tradition to file
itself under someone else's categories — Nyāya epistemology under
"epistemology", Ubuntu ethics under "ethics". A closed enum cannot express a
tradition's own conceptual vocabulary at all.

**Decision.** The vocabulary lives in `assets/content/taxonomy.json` and is
loaded into a `Taxonomy` held by the corpus. Entities carry `Set<String>` of
term ids. Terms nest via `parent`, so "Mesoamerican" sits under "Indigenous"
and a reader can browse at whichever level they are thinking at; queries and
filters resolve through ancestry, so filing an entry more precisely never makes
it harder to find.

`TaxonomyKind` — tradition, branch, era — stays a closed enum, and legitimately:
it names the axes the product classifies along, not the values on those axes.
Adding a tradition must never need a code change; adding a whole new *kind* of
classification is a real architectural decision.

**What replaced the compiler.** Opening the vocabulary gave up the guarantee
that an id is real, so the guarantee moved rather than vanished.
`findIntegrityViolations` rejects an unknown id, an id used as the wrong kind, a
term whose parent does not exist, and a term with no Persian name — the
bilingual constraint the label switch used to enforce by refusing to compile.
`test/domain/taxonomy_test.dart` exercises each, and exercises the central claim
directly: a tradition appearing nowhere in the source still builds, classifies,
resolves and answers ancestry queries.

**Cost.** Content can now be wrong in a way it previously could not, and the
error surfaces at load rather than at compile. The check runs on every load and
in CI, so the window is a test run rather than a release.

---

### ADR 18 — Script coverage is a test, not an assumption

**Context.** ADR 13 bundled a face per script and asserted that every style
declares a fallback chain. That test proves the *chain exists*; it cannot prove
the chain can draw the content. Twice it could not: `Ἐπίκτητος` shipped as
`▯πίκτητος`, and `孔子` shipped as two empty boxes, because nothing bundled
carried a single CJK glyph. Both were found by looking at a screenshot, which is
not a method.

**Decision.** `test/core/design/script_coverage_test.dart` reads the `cmap`
table out of every bundled font file and checks every character of every
authored string — content and interface — against the fallback chain the app
actually uses, in both languages. A script the corpus uses and the fonts cannot
draw is a failing test.

The test paid for itself immediately: written to cover the CJK gap, it found
that every Sanskrit term in the Indian philosophy entries — `शून्यता`, `धर्म` —
was also rendering as empty boxes, which nobody had noticed.

**Decision (fonts).** Noto Serif SC, JP and KR, plus Noto Serif Devanagari.
Three CJK faces rather than one because Han unification gives the writing
systems the same codepoint for characters they draw differently; a single face
would set every Japanese name in Chinese letterforms. Each is subset to its own
national standard — GB 2312, JIS X 0208, KS X 1001 — by
`tool/subset_cjk_fonts.py`.

**Why national standards rather than "what content uses".** Subsetting to the
characters in today's corpus would make the next entry render as boxes, and
would fail any reader typing CJK into a note. The three standards are the
everyday repertoires of the writing systems, they are stable, and Python
enumerates them exactly — no frequency table to source or trust.

**Cost.** About 7.2 MB more in the bundle, taking the fonts from 2.3 MB to
9.5 MB. That is the largest single cost in the app, accepted because a
reference work that cannot print the name of the philosopher it has an article
about has failed at its first job. The fallback chain also cannot resolve a
Han codepoint to all three regional forms at once; SC wins, which is recorded
in `AppTypography.cjkFamilies` rather than left to be discovered.

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
