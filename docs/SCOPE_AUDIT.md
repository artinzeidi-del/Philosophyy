# Global scope & architecture audit

**Against:** MASTER SCOPE REALIGNMENT — Global Philosophy Reference Super App
**Commit audited:** `c0dc6df`
**Method:** repository inspected directly; every count below produced by running
against the actual files, not recalled.

**Baseline, re-verified for this audit:**
`flutter analyze --fatal-infos --fatal-warnings` → no issues.
`flutter test` → 164 passing. Both RUNTIME VERIFIED in this session.

---

## A. CURRENT STATE

| Layer | What exists |
| --- | --- |
| Domain | 7 content entities: Philosopher, Work, Concept, School, Argument, Quote, Source. Plus Relation, ContentSection/Article, and 4 reader-data entities. No Flutter dependency. |
| Data | `KnowledgeBase` (whole corpus in memory), `AssetKnowledgeRepository` (8 bundled JSON files), strict `JsonReader`, `StoredUserDataRepository` (versioned JSON, salvage-on-corruption). |
| Core | Design tokens, two themes, language-aware typography with 3-script fallback, motion system, hand-written search index + Unicode normaliser, WCAG contrast maths. |
| App | Riverpod providers, go_router with 5 tabs + article routes, settings, library. |
| Features | Home, Explore, Search, Library, Settings, one Article screen serving 4 entity kinds. |
| l10n | ARB (en/fa), zero untranslated; taxonomy labels bilingual in Dart. |
| Corpus | **98 entities total** — 14 philosophers, 14 works, 12 concepts, 6 schools, 10 quotes, 2 arguments, 24 sources, 16 relations. |
| Tests | 164 across 9 files: contrast, motion, typography, normaliser, search, content integrity, routing, persistence, app smoke, library flow. |

---

## B. COMPLETED (genuinely finished, evidence-backed)

- **Content integrity enforcement.** Every cross-reference validated; dangling
  links fail at load and in CI. 15 assertions.
- **Editorial rules in code.** Verified quotations require a citation; anything
  less requires an explanatory note; caveated quotes cannot be shared. Enforced
  in the mapper, not by review.
- **Bilingual rendering end to end.** RTL/LTR, Persian digits, per-language type
  scale, three scripts (Latin / Arabic / polytonic Greek) with fallback chains.
- **Accessibility floor.** WCAG AA asserted for every colour pair, AAA for body
  text; reduced-motion honoured by every animated primitive, asserted both ways.
- **Reader-owned data.** Bookmarks, notes, reading position — versioned storage,
  refuses future schemas, salvages unreadable documents, survives language
  changes. 42 assertions.
- **Search across scripts.** One philosopher findable by 6 name forms in 3
  scripts.

---

## C. BROKEN

**Nothing is broken.** Analysis is clean, all 164 tests pass, the release web
build runs in Chromium with zero JavaScript errors.

The problems below are *architectural ceilings*, not defects. That distinction
matters: the app works correctly at its current size and will stop being
extensible long before it stops being correct.

---

## D. TECHNICAL DEBT (known, not blocking)

| # | Item |
| --- | --- |
| D1 | Highlighting is fully modelled, stored, re-anchored and tested — with **no interface to create one**. Code that cannot be reached. |
| D2 | Article depth is under-fed: most entries stop at `standard`; none reach `research`. |
| D3 | Search prefix/fuzzy matching scans the whole token list linearly. Fine now, needs a trie later. |
| D4 | No Android or iOS build has ever been attempted. Only web has run. |
| D5 | CI has never executed on GitHub Actions. |
| D6 | `_TargetCard` for a missing entity renders a card with a no-op tap. |

---

## E. ARCHITECTURAL RISKS — the real findings

### 🔴 E1 (P0) — The philosophical taxonomy is a closed enum

This is the **single most serious violation of the North Star**, and §56 names it
explicitly: *"If a new feature introduces a hardcoded philosophical taxonomy that
excludes major traditions: FLAG IT."*

**Measured:** `Tradition` has **16** members. `PhilosophyBranch` has **18**.
`EntityKind` 7, `RelationType` 10, `SourceKind` 7 — all Dart `enum`s.

The North Star's coverage map requires, among many others: Korean, Vietnamese,
Ethiopian, Ancient Egyptian, Mesoamerican/Maya/Aztec, Andean, Indigenous
Australian, Pacific Island, First Nations, Tibetan. **None of these can be
expressed without editing Dart and recompiling the app.**

It is worse than a single enum: `TaxonomyLabels` switches *exhaustively* over
both enums in a second file, so adding one tradition is a two-file code change
plus a rebuild — for what is fundamentally a piece of content.

There is also a subtler failure. §9 says *"do not force all of these into Western
philosophical categories"* and *"the data model must allow traditions to preserve
their own conceptual frameworks."* A fixed 18-member `PhilosophyBranch` list
derived from the Western division of philosophy does exactly the forcing the
North Star forbids: it asks Nyāya epistemology and Ubuntu ethics to file
themselves under categories drawn from a different tradition.

### 🔴 E2 (P0) — `LocalizedText` is hard-wired to exactly two languages

```dart
final String en;   // required
final String? fa;  // optional
```

with exhaustive `switch (language)` at every call site. §44 says *"do not design
the architecture in a way that makes adding more languages impossible later."*
Adding Arabic, French or Turkish today is a breaking change to every entity,
mapper, widget and test. English is also structurally privileged as the required
pivot — which is defensible as an editorial policy but is currently a *type-system*
fact, not a policy that could be revisited.

### 🟠 E3 (P1) — Relations carry no epistemic status

Current `Relation`: `subject, type, object, note, sourceIds`. **No confidence
field** (`grep` for confidence in `lib/domain/` → 0 hits).

§40 requires relations to eventually carry *source, confidence, historical
context, scholarly status, notes, bilingual explanation*. §42 is explicit that
*"Philosopher X influenced Philosopher Y"* must be able to carry its own
evidence, and that relations can be contested.

Today the product can say "Aristotle criticised the Theory of Forms" and cite it,
but cannot say "this influence is asserted by some scholars and disputed by
others" — despite already having that vocabulary (`ClaimType`) for prose.

`RelationType` also has **10** of the ~26 relations the North Star lists. Missing:
`discusses`, `expands`, `contradicts`, `supports`, `rejects`, `contains`,
`derivedFrom`, `teaches`, `associatedWith`.

### 🟠 E4 (P1) — Whole corpus parsed and fully validated on every launch

`AssetKnowledgeRepository.load()` parses all 8 files, builds the graph, then runs
`assertIntegrity()` across every cross-reference — on **every app start**. Then
`SearchIndex.build()` indexes the entire corpus in memory.

At 98 entities this is imperceptible. At the tens of thousands the North Star
demands it is a multi-second startup, a large resident heap, and a validation
pass that belongs in CI rather than on a reader's phone.

ADR 2 anticipated this and named the threshold. **We are not near it yet** — but
E1 and E2 must be fixed *before* the corpus grows, because migrating 50 entities
is trivial and migrating 5,000 is a project.

### 🟠 E5 (P1) — One monolithic JSON file per entity type

`philosophers.json` is already 58 KB for 14 entries. At 1,000 philosophers it is
a ~4 MB single file: unreviewable in a diff, unmergeable between editors, and
re-parsed in full to change one sentence. §49 calls for a real content pipeline.

### 🟡 E6 (P2) — Missing entity kinds

Present: Philosopher, Work, Concept, School, Argument, Quote, Source (7).
§41 asks for 20. Absent: **Movement, Tradition-as-entity, Branch-as-entity, Era,
Period, Debate, PhilosophicalProblem, Event, Location, Lesson, Topic,
ComparativeStudy, TimelineEntry**.

`PhilosophicalProblem` is the most valuable of these — §39's problem-centric
discovery is the feature most likely to distinguish this product, and nothing in
the model supports it.

---

## F. CONTENT GAPS

The corpus is **98 entities**. Measured against the North Star's coverage map,
what exists is a proof that the pipeline works, not a reference work.

| Tradition (North Star §3–§16) | Present |
| --- | --- |
| Ancient Greek | Socrates, Plato, Aristotle, Epictetus — of ~17 named schools |
| Islamic / Persian | Ibn Sīnā, al-Ghazālī, Mullā Ṣadrā — of 13+ named thinkers, 15 named schools |
| Indian | Nāgārjuna only — of ~20 named schools |
| Chinese | Confucius only — of 9 named thinkers |
| Japanese / Korean / Vietnamese | **none** |
| African | **none** (Du Bois is filed as American/African) |
| Indigenous (global) | **none, and not representable** — see E1 |
| Latin American | **none** |
| Jewish | **none** |
| Early Modern | Descartes only |
| German Idealism | Kant only |
| 19th century | Nietzsche only |
| Analytic | **none** |
| Continental | Beauvoir only |
| Pragmatism | **none** |

Branch coverage (§17–§37) is similarly thin: no entries yet for philosophy of
technology/AI, law, mathematics, biology, education, or economics, despite all
six existing as taxonomy values.

**This gap is expected and correct at this stage** — §49 warns against turning
the corpus into a data-dump, and §53 says build the foundation first. It is
recorded here so nobody mistakes seed data for coverage.

---

## G. RECOMMENDED ROADMAP

The ordering principle: **fix what gets harder with every entity added, before
adding entities.** E1 and E2 are cheap now and expensive later.

1. **Open the taxonomy** (E1). Traditions, branches, eras and relation types
   become *content*, loaded from JSON with stable ids, not Dart enums.
2. **Generalise `LocalizedText`** (E2) to a language-keyed map, with English as
   an editorial-policy pivot rather than a type-level one.
3. **Give relations epistemic status** (E3) and extend the relation vocabulary.
4. **Split content into per-entity files** (E5) with a manifest.
5. **Move full integrity validation to CI**; keep a cheap referential check at
   runtime (E4).
6. Then, and only then, resume vertical slices: `PhilosophicalProblem` →
   `Movement`/`Period` → Timeline → Knowledge-graph UI.
7. Content expansion runs continuously alongside, tradition by tradition,
   starting with the ones currently absent entirely.

---

## H. PRIORITY

| Priority | Items |
| --- | --- |
| **P0 — must fix now** | E1 open taxonomy · E2 multi-language `LocalizedText` |
| **P1 — before the next content slice** | E3 relation confidence + vocabulary · E5 content file splitting · E4 validation moved to CI · D1 highlighting UI (built but unreachable) |
| **P2 — later** | E6 missing entity kinds (Problem first) · D2 content depth · D3 search trie · D4 mobile builds · D5 CI first run |
| **P3 — future** | Learning system · knowledge-graph UI · comparative studies · CMS · sync |

### On the request for a nicer Persian font and richer UI

§56 requires flagging this, so: **the UI polish request is P2 and the Persian
font is P1-cheap.** Improving the Persian face genuinely serves §44 —
bilingual-first is a content-quality property, not decoration, and the current
Vazirmatn is a UI sans being asked to carry long-form reading. Swapping in a face
designed for sustained Persian reading is a contained change worth doing.

Broader visual polish, however, would be the third consecutive session weighted
toward the interface while the taxonomy cannot express half the world's
philosophical traditions. That is precisely the drift §56 asks me to name. My
recommendation is: **P0 taxonomy + i18n first, Persian reading face alongside it,
broader UI work after.**

---

## I. IMPLEMENTATION PLAN (P0, next session)

**E1 — Open the taxonomy**

| File | Change |
| --- | --- |
| `lib/domain/value_objects/taxonomy.dart` | `Tradition`/`PhilosophyBranch` enums → value classes holding a stable `id`, resolved through a registry |
| `lib/domain/value_objects/taxonomy_registry.dart` | *new* — lookup, validation, ordering |
| `assets/content/taxonomy.json` | *new* — traditions, branches, eras as content, bilingual, with parent/child so traditions can nest |
| `lib/core/l10n/taxonomy_labels.dart` | exhaustive switches deleted; labels come from the registry |
| `lib/data/content/content_mappers.dart` | `enumSet` → registry-validated id sets |
| `lib/data/content/knowledge_base.dart` | integrity check extended to taxonomy references |
| `assets/content/*.json` | unchanged ids — existing 16 traditions/18 branches become the first registry entries |
| `test/domain/taxonomy_test.dart` | *new* — unknown id rejected; every id used by content resolves; adding a tradition needs no Dart change |

**E2 — Multi-language `LocalizedText`**

| File | Change |
| --- | --- |
| `lib/domain/value_objects/localized_text.dart` | `{en, fa}` → `Map<String, String>` keyed by language code; `resolve()` walks a fallback chain |
| `lib/domain/value_objects/app_language.dart` | remains the *shipped* set; decoupled from what content can hold |
| `lib/data/content/content_mappers.dart` | read every language key present, not just two |
| call sites (~12 widgets/tests) | `.en` / `.fa` → `.inLanguage(code)` |

**Risk:** E2 touches many files. Mitigation: the 164 existing tests are the
safety net, and `LocalizedText` keeps `en`/`fa` convenience getters during the
transition so the change lands incrementally rather than as one large rewrite.

**Not in scope for that session:** new entity kinds, content expansion, broader
UI work.
