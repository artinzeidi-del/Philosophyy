# Project checkpoint

**Date:** 2026-08-14
**Session:** 4 (scope realignment — the content architecture)
**Branch:** `claude/philosophy-super-app-gzaw5t`

## What this session was for

The previous three sessions built a foundation, a visual identity and a
persistence layer, and each ended with the interface a little further ahead of
the content architecture. This session began by auditing the repository against
the stated North Star — a reference work for the philosophy of the whole world —
and then worked through what the audit found, in priority order.

`docs/SCOPE_AUDIT.md` holds the audit. Every figure in it was produced by
running something against the files, not recalled.

## Starting state, verified

Session 4 began from commit `555d945`: analysis clean, 177 tests passing, the
web build running. Re-verified by running it rather than taken from the previous
report.

## What the audit found, and what was done about it

### The taxonomy was a closed enum — fixed (`9eec7a8`)

Sixteen traditions and eighteen branches compiled into the binary. Korean,
Vietnamese, Tibetan, Ethiopian, Mesoamerican, Andean and every Indigenous
tradition could not be *named* by the product without a Dart change and a
release. A reference work whose vocabulary of world traditions is fixed at
compile time has decided in advance which philosophies exist.

The vocabulary is content now: 62 terms in `assets/content/taxonomy.json`,
bilingual, nested so a reader can browse at whichever level they are thinking
at. Filing an entry more precisely no longer makes it harder to find —
selecting "Ancient Greek" returns Epictetus, who is tagged only `hellenistic`.

The compiler's guarantee that an id is real did not vanish; it moved to the
corpus integrity check and to `test/domain/taxonomy_test.dart`. See ADR-017.

### `LocalizedText` capped content at two languages — fixed (`b80737d`)

Same shape of ceiling, one layer down. A `translations` map keyed by BCP-47
subtag now holds any further language, and search indexes all of them including
ones the interface cannot yet display. No call site changed. See ADR-019.

### The graph asserted everything with equal certainty — fixed (`1456dfd`)

Ten relation types and no notion of how well established an edge was. The
product already refused a uniform tone of authority for quotations and for
prose; the graph was the one place it still spoke in one.

`RelationConfidence` — documented, accepted, probable, contested, speculative —
now sits on every edge, and `Relation.isSupported` makes the level mean
something: a documented edge must cite a text, and a contested one must say who
argues it. Twenty-six relation types, including `taught`, `commentedOn`,
`translated` and `preserved` — without which the commentary traditions and the
doxographers cannot be described at all. See ADR-021.

### Scripts the corpus uses could not be printed — fixed (`b561250`)

`孔子` rendered as two empty boxes. Nothing bundled carried a single CJK glyph.

The fonts are now under test: `script_coverage_test.dart` reads the `cmap` table
out of every bundled file and checks every character of every authored string
against the fallback chain the app actually uses, in both languages. It paid for
itself on the first run by finding that every Sanskrit term in the Indian
philosophy entries was also rendering as boxes. See ADR-018.

### Persian had an interface face but no reading face — fixed (`eccd178`)

Requested directly by the user, and independently P1 in the audit. Noto Naskh
Arabic sets Persian content; Vazirmatn stays for chrome. Amiri was the more
beautiful candidate and was rejected on evidence: rendering the real corpus in
it showed Arabic conventions applied to Persian. See ADR-020.

### Highlighting was built and unreachable — fixed (`b98b600`)

The model, storage, codec, re-anchoring and their tests all existed; nothing in
`lib/features/` touched them. Marks can now be made, are re-anchored rather than
trusted, and appear in the library. See ADR-022.

## Status of the work

Vocabulary as required: PLANNED / IMPLEMENTED / STATICALLY VERIFIED / RUNTIME
VERIFIED / NOT VERIFIED.

| Area | Status |
| --- | --- |
| Open taxonomy, nested, integrity-checked | RUNTIME VERIFIED |
| `LocalizedText` carrying any language | STATICALLY VERIFIED (no content uses a third language yet) |
| Relation confidence and extended vocabulary | RUNTIME VERIFIED |
| CJK and Devanagari rendering | RUNTIME VERIFIED |
| Persian reading face | RUNTIME VERIFIED |
| Highlighting: mark, paint, re-anchor, remove, list | RUNTIME VERIFIED |

"Runtime verified" here means the release web build was loaded in Chromium and
the behaviour was seen on screen, not that a test asserted it.

## Verification actually run

| Command | Result |
| --- | --- |
| `dart format lib test` | clean |
| `flutter analyze --fatal-infos --fatal-warnings` | No issues found |
| `flutter test` | 218 passing, 0 failing |
| `flutter build web --release --no-web-resources-cdn` | built |
| Chromium against the release build | no console or page errors |

`--no-web-resources-cdn` is needed only in this sandbox, where the proxy blocks
the CanvasKit CDN. CI builds without it.

Tests grew from 177 to 218. The new ones are `taxonomy_test.dart`,
`localized_text_test.dart`, `relation_test.dart`, `script_coverage_test.dart`,
and four highlighting flows in `library_flow_test.dart`.

## Defects found and fixed this session

- **CJK rendered as empty boxes.** Found by looking at a screenshot of the
  Confucius entry. Now impossible to reintroduce without failing a test.
- **Devanagari rendered as empty boxes.** Found by the test written for the
  previous item, in content nobody had reported a problem with.
- **`RelationType.opposed` declared symmetric while carrying an asymmetric
  `inverseId`.** Dead but misleading; found by a new test.
- **A crash in the library highlight card**, introduced and caught in the same
  session: `CrossAxisAlignment.stretch` in a `ListView` forces infinite height.
  Every reader with a highlight would have hit it.
- **The highlight action was unreachable on web desktop**, because Flutter's
  selection toolbar does not appear there. Found by trying it in a browser
  rather than by trusting the widget test.

## What is still not done

Stated plainly so it is not mistaken for finished work.

- **Content volume.** The corpus is small: a dozen philosophers, a handful of
  concepts, works, schools and arguments. The *architecture* now supports the
  world's traditions; the *content* does not yet cover them. This is now the
  largest gap, and it is editorial work rather than engineering.
- **Content is eight monolithic files.** The audit recommended splitting them
  per entity. Not started; it becomes painful as the corpus grows, not before.
- **Missing entity kinds.** `PhilosophicalProblem` is the first one worth
  adding — problems are how a reader without a name to search for actually
  enters philosophy.
- **The salvage path has no interface.** Unreadable saved data is preserved
  (ADR-016) but there is still no way for a reader to recover it.
- **No observability.** No error reporting, logging or metrics.
- **A single fallback chain cannot resolve a Han codepoint to all three
  regional forms.** Simplified Chinese wins. Fixing it properly means choosing
  a face per content language, which is a larger design than it looks.

## Notes for whoever picks this up

The audit's priority order was followed, with one deliberate departure: the CJK
font work was done out of sequence, because the defect surfaced while verifying
the taxonomy refactor and was cheap to fix while it was in hand.

One audit item needed no work: "move full integrity validation to CI" was
already satisfied — `.github/workflows/ci.yml` runs `flutter test`, which loads
the shipped corpus and calls `assertIntegrity()`.
