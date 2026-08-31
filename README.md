# Philosophia

A bilingual (فارسی / English) reference, library and learning platform for world
philosophy, built with Flutter.

> **Status: the reference is written; the product around it is not.** Every
> entry in the corpus is written to three reading depths in both languages and
> every claim carries its sources. The reader, the learning tools and the graph
> view do not exist yet. See [`docs/STATUS.md`](docs/STATUS.md) for what is and
> is not done, with every number produced by running against the files.

## What is actually here

| Area | State |
| --- | --- |
| Design system, light + dark themes | Built, WCAG AA verified by test |
| Motion system, reduced-motion honoured | Built, 14 tests |
| Script coverage: Latin, Arabic, polytonic Greek | Built, 12 tests |
| Bilingual architecture (fa/en, RTL/LTR) | Built, verified end to end |
| Domain model and content pipeline | Built, integrity-checked by test |
| Search (cross-script, fuzzy, Persian-aware) | Built, 74 tests |
| Home, Explore, Search, Settings, Article screens | Built |
| Glossary, primer, library (saves, notes, highlights) | Built |
| Quiz, built from the corpus, with nine ranks of progress | Built, 28 tests |
| Corpus | 192 philosophers, 61 concepts, 186 works, 29 schools, 238 quotations, 12 arguments, 303 sources, 76 glossary terms |
| Continuous reader, spaced review, graph view | **Not started** |

## Running it

The project targets Flutter 3.47 / Dart 3.13.

```bash
flutter pub get
flutter gen-l10n     # generated localisations are not committed
flutter run          # or: flutter build web --release
```

## Verifying it

```bash
flutter analyze                 # must report no issues
flutter test                    # 988 tests
flutter build web --release     # must succeed
```

The tests are not decoration. Five of them are load-bearing:

- `test/core/design/contrast_test.dart` fails the build if any colour pair in
  either theme drops below WCAG AA.
- `test/data/content_integrity_test.dart` loads the corpus that actually ships
  and fails on any dangling cross-reference, any untranslated entry, and any
  quotation whose attribution is not supported by what the content policy
  requires.
- `test/app/app_smoke_test.dart` boots the real app and drives it through
  navigation in both languages and both themes.
- `test/core/design/motion_test.dart` fails if any animated primitive stops
  honouring the platform's reduced-motion setting — and also if it stops
  animating when motion is allowed, so disabling everything is not a way to pass.
- `test/core/design/typography_test.dart` fails if any text style loses its
  font-fallback chain, which is how Greek and Arabic names silently turn into
  empty boxes.

## Layout

```
lib/
  app/          Application shell: providers, router, settings
  core/         Cross-cutting: design system, search, formatting, errors
  data/         Content loading, parsing and the in-memory knowledge base
  domain/       Entities and value objects; no Flutter dependency
  features/     One directory per screen area
  l10n/         ARB files (generated output is gitignored)
assets/
  content/      The corpus, as JSON
  fonts/        Vazirmatn (Persian) and Spectral (English), both SIL OFL 1.1
docs/           Architecture decisions, content policy, project status
```

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — structure and the decisions
  behind it, with the trade-offs stated
- [`docs/CONTENT_POLICY.md`](docs/CONTENT_POLICY.md) — the editorial rules,
  including the ones enforced by tests
- [`docs/STATUS.md`](docs/STATUS.md) — what is built, what has been measured
  and what is still missing

## Licences

The application code is in this repository. Bundled third-party assets:

- **Vazirmatn** by Saber Rastikerdar — SIL Open Font License 1.1 (Arabic script)
- **Spectral** by Production Type — SIL Open Font License 1.1 (Latin reading)
- **GFS Didot** by the Greek Font Society — SIL Open Font License 1.1
  (polytonic Greek)

All three licences are bundled as assets and registered with Flutter's licence
registry, so they appear in the app's own About screen.

Philosophical content is written for this project from primary texts and
academic reference works. Sources are recorded per claim; see the content
policy for the rules governing them.

## Screenshots

Captured from the release web build running in Chromium, with no JavaScript
errors. Left to right: English light, Persian light (fully right-to-left,
Persian digits, Vazirmatn), English dark.

| English | فارسی | Dark |
| --- | --- | --- |
| ![English, light](docs/screenshots/01-home-en-light.png) | ![Persian, light](docs/screenshots/02-home-fa-light.png) | ![English, dark](docs/screenshots/03-home-en-dark.png) |

An article, and the same layout carrying three scripts at once — the Greek is
polytonic and the Arabic runs right-to-left inside an English page:

| Article | Mixed scripts |
| --- | --- |
| ![Article](docs/screenshots/05-article-en-light.png) | ![Mixed scripts](docs/screenshots/06-article-scripts.png) |
