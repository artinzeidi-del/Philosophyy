#!/usr/bin/env python3
"""Cut the script-only fonts down to the characters the content actually uses.

Nine of the eleven bundled faces exist for one job: printing a name in its own
script. Nezahualcoyotl's Nahuatl, Dogen's Japanese, Zera Yacob's Ge'ez. The app
never sets a paragraph in them.

They were shipping whole. The three CJK faces alone came to seven megabytes for
content that uses eighty-six ideographs, and Noto Sans Egyptian Hieroglyphs
carried 1,085 glyphs to draw four. On a phone connection that is most of the
download, spent on glyphs nobody will see.

Subsetting to exactly what the content uses is only safe if something notices
when the content grows past the subset. `test/core/design/font_coverage_test.dart`
reads every character in `assets/content` and asserts a bundled face has a glyph
for it, so adding a Korean philosopher without re-running this fails the build
rather than shipping a row of empty boxes.

## Why the sources live in tool/fonts

The first version of this script read `assets/fonts` and wrote back to it, which
works exactly once. Every later run subsets an already-subset face, so the
operation only ever removes glyphs — and when the content grew to include 氣 and
दुःख, re-running the script could not put them back. The faces had to be dug out
of the commit that first cut them.

So the pristine faces live in `tool/fonts` and are never touched; every run
rebuilds `assets/fonts` from them. That directory is not in the pubspec asset
list, so the nine megabytes stay in the repository and out of the download.

Usage:  python3 tool/subset_fonts.py [--check]

`--check` reports what would change without writing, which is what CI wants.
"""
import glob
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Which faces are "script-only" — bundled to print names, never to set prose.
# The reading and interface faces (Spectral, Vazirmatn, Noto Naskh, GFS Didot)
# are deliberately absent: they set whole paragraphs, and a paragraph face
# subset to today's vocabulary breaks on tomorrow's.
SCRIPT_ONLY = {
    'notoserifcjk': None,          # ranges computed below
    'notoserifdevanagari': None,
    'notoserifbengali': None,
    'notoserifhebrew': None,
    'notoserifethiopic': None,
    'notoseriftibetan': None,
    'notosansegyptianhieroglyphs': None,
}

# Always keep, in every subset: the space and the punctuation that can appear
# inside a name, so a mixed string never has to fall back mid-word.
ALWAYS = set(' ·—–-()[],.:;!?\'"«»‹›‌‍')


def content_characters() -> set:
    """Every character the shipped content and the UI strings can display."""
    found = set()

    def walk(node):
        if isinstance(node, str):
            found.update(node)
        elif isinstance(node, dict):
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    for path in sorted(glob.glob(str(ROOT / 'assets/content/*.json'))):
        walk(json.load(open(path, encoding='utf-8')))
    for path in sorted(glob.glob(str(ROOT / 'lib/l10n/*.arb'))):
        walk(json.load(open(path, encoding='utf-8')))
    return found


def main() -> int:
    check = '--check' in sys.argv
    chars = content_characters() | ALWAYS
    text = ''.join(sorted(chars))

    total_before = total_after = 0
    changed = []

    for family in sorted(SCRIPT_ONLY):
        originals = sorted(glob.glob(str(ROOT / f'tool/fonts/{family}/*.ttf')))
        if not originals:
            print(
                f'no pristine face for {family} in tool/fonts — recover it '
                f'before subsetting, or this run will only cut further',
                file=sys.stderr,
            )
            return 1
        for font in originals:
            source = Path(font)
            target = ROOT / 'assets/fonts' / family / source.name
            before = target.stat().st_size if target.exists() else 0
            out = target.with_suffix('.subset.tmp')

            subprocess.run(
                [
                    'pyftsubset', str(source),
                    f'--output-file={out}',
                    f'--text={text}',
                    # Complex scripts are shaped by their layout tables. Drop
                    # them and Devanagari conjuncts and Tibetan stacks come
                    # apart into loose letters that spell nothing.
                    '--layout-features=*',
                    '--notdef-outline',
                    '--recommended-glyphs',
                    '--drop-tables+=DSIG',
                ],
                check=True,
                capture_output=True,
            )
            after = out.stat().st_size
            total_before += before
            total_after += after
            if after != before:
                changed.append((source.name, before, after))
            if check:
                out.unlink()
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                out.replace(target)

    for name, before, after in changed:
        print(f'{name:44} {before/1024:9.1f} KB -> {after/1024:8.1f} KB')
    saved = total_before - total_after
    print(f'\n{"TOTAL":44} {total_before/1024/1024:9.2f} MB -> '
          f'{total_after/1024/1024:8.2f} MB   (saved {saved/1024/1024:.2f} MB)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
