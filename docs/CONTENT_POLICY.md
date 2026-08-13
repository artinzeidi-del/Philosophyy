# Content policy

The rules governing what may appear in this product's corpus. Several of them
are enforced by tests rather than by review, and those are marked **[enforced]**.

## 1. Nothing bibliographic may be invented

A plausible-looking citation is worse than no citation, because it survives
checking by everyone who does not check it.

- No DOI, ISBN, page number, publication year or URL may be written from memory
  or reconstructed from a pattern. If the detail is not known, the field is left
  empty.
- **[enforced]** `content_integrity_test.dart` asserts that no source in the
  corpus carries an `identifier` or `pages` value. The corpus currently cites
  works, not pages. When a real page reference is added — checked against the
  actual publication — that test must be updated deliberately, which makes the
  addition a decision rather than an accident.
- Citations use canonical locators (Stephanus for Plato, Bekker for Aristotle,
  A/B for Kant) rather than page numbers, because those are stable across every
  edition and translation and a page number is not.

## 2. Quotations carry their provenance

Popular philosophy quotation is riddled with misattribution. Every quotation in
the corpus has an attribution status:

| Status | Meaning | Required support |
| --- | --- | --- |
| `verified` | Traced to a specific passage | **A citation** |
| `probable` | Accepted by scholarship, passage not located | An explanatory note |
| `disputed` | Scholars disagree about authenticity | An explanatory note |
| `misattributed` | Known not to be their words | An explanatory note |
| `unknown` | No source traced | An explanatory note |

- **[enforced]** The content mapper rejects a quotation marked `verified` with no
  citation, and any other status with no note. A quotation cannot enter the app
  claiming more confidence than its evidence supports.
- **[enforced]** A quotation needing a caveat is never shareable. Sharing a
  misattributed line is exactly how misattribution spreads.
- Misattributed quotations are kept deliberately. The most useful thing a
  reference work can do with a famous fake is to say plainly that it is one.

## 3. Kinds of claim are distinguished

Reference writing slides between "Aristotle was born in Stagira", "Aristotle is
best read as a naturalist", and "scholars dispute the authenticity of the
*Categories*" — three very different sentences in one tone of authority.

Every passage is tagged `fact`, `interpretation`, `scholarly-disagreement`,
`hypothesis` or `disputed`, and the interface marks anything that is not plain
fact.

- **[enforced]** Any passage tagged as something other than `fact` must cite at
  least one source. Marking a claim as interpretation and then not saying whose
  interpretation it is helps nobody.

## 4. Scholarly disagreement is shown, not resolved

Where the scholarship genuinely divides, the entry says so and presents the
competing positions. It does not pick a winner for the reader's convenience.
Existing examples in the corpus: the Socratic problem, the politics of the
*Republic*, whether al-Ghazālī ended philosophy in the Islamic world, the status
of Beauvoir's relation to Sartre.

## 5. Dates keep their uncertainty

Most ancient and medieval dates are scholarly estimates. Every year carries an
explicit precision (`exact`, `circa`, `decade`, `century`), and the interface
renders the qualification. Encoding an estimate as exact is a falsification, and
the domain model has no way to express a date without saying how well it is
known.

## 6. Coverage is global, and that is checked

A product claiming to cover world philosophy fails silently if its content
drifts back toward the European canon, because nothing breaks when it does.

- **[enforced]** The corpus must span at least six traditions.
- Traditions are a set on each entity, never a single classification: Ibn Sīnā is
  both Islamic and Persian, and forcing one falsifies the history.

## 7. Both languages, always

The product is bilingual by construction, not English-first with a translation
pass.

- **[enforced]** Every entity must have a one-line summary in both languages.
- **[enforced]** Every authored article section must have text in both languages.
- Where a translation is genuinely absent, the model stores `null` rather than a
  duplicated English string, and the interface tells the Persian reader plainly
  that they are being shown English. Silent fallback is a lie about coverage.
- Philosophical terminology follows established Persian usage rather than literal
  translation.

## 8. Cross-references must resolve

- **[enforced]** Every identifier in the corpus — every related concept, every
  cited source, every relation endpoint, every work's author — must resolve to
  something that exists. A reference work dies by a thousand dead links.
- The check runs at app startup as well as in tests, so a broken link fails
  where a developer sees it rather than becoming a blank screen for a reader.

## 9. Third-party material is attributed

Every source record carries its rights position. Bundled fonts ship with their
licences as assets, registered with Flutter's licence registry so they appear in
the app's About screen.

## What is not yet enforced

Stated plainly so that the gap is not mistaken for coverage:

- No check that a Persian translation is *good*, only that it exists.
- No editorial review workflow. The pipeline described in the original brief
  (research → draft → source check → academic review → translation → QA →
  publish) is currently one person writing carefully.
- No content versioning or audit trail.
