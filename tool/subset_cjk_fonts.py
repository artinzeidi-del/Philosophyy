#!/usr/bin/env python3
"""Rebuilds the bundled CJK subsets in assets/fonts/notoserifcjk/.

## Why the fonts are subset at all

Noto Serif CJK is about 25 MB across the three regional faces. Shipping that
whole would more than double the app for glyphs a reader will mostly never see.
Subsetting brings it to roughly 7 MB, which an app that already bundles its
entire corpus offline can carry.

## Why three faces rather than one

Han unification gives Chinese, Japanese and Korean the same codepoint for
characters they draw differently — U+5B78/U+5B66 (學/学) is the familiar
example, but the divergence is routine. One face would print every Japanese
name in Chinese letterforms. Each regional face is therefore subset to its own
national standard, so a name is set the way its own tradition writes it.

## Why the character set is defined by national standards

"The characters our content happens to use today" is not a character set: the
next entry added would silently render as empty boxes, and worse, so would
anything a reader typed into a note. GB 2312, JIS X 0208 and KS X 1001 are the
standard everyday repertoires of the three writing systems, they are stable,
and Python can enumerate them exactly — no frequency table to source, trust or
keep current.

Run from the repository root:

    pip install fonttools
    python3 tool/subset_cjk_fonts.py

`test/core/design/script_coverage_test.dart` fails if content uses a character
these subsets do not cover, so drift is caught rather than shipped.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# Upstream is pinned to the raw path rather than a release archive: the release
# asset names have changed between versions, the raw path has not.
UPSTREAM = (
    "https://raw.githubusercontent.com/notofonts/noto-cjk/main"
    "/Serif/SubsetOTF/{region}/NotoSerif{region}-Regular.otf"
)
LICENSE_URL = (
    "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE"
)
OUT_DIR = Path("assets/fonts/notoserifcjk")

# Punctuation and fullwidth forms, shared by all three writing systems.
PUNCTUATION = {chr(c) for c in range(0x3000, 0x3040)} | {
    chr(c) for c in range(0xFF01, 0xFF61)
}
# Hiragana, katakana and the halfwidth katakana block.
KANA = {chr(c) for c in range(0x3040, 0x3100)} | {
    chr(c) for c in range(0xFF66, 0xFFA0)
}


def national_standard(codec: str) -> set[str]:
    """Every character a double-byte national standard encodes.

    Enumerating the codec is exact where a character list copied from anywhere
    else would be a claim needing verification.
    """
    characters: set[str] = set()
    for first in range(0xA1, 0xFF):
        for second in range(0xA1, 0xFF):
            try:
                characters.add(bytes([first, second]).decode(codec))
            except UnicodeDecodeError:
                continue
    return characters


REGIONS = {
    # Simplified Chinese: GB 2312.
    "SC": lambda: national_standard("gb2312") | PUNCTUATION,
    # Japanese: JIS X 0208, which carries kanji; kana added explicitly because
    # the halfwidth block sits outside it.
    "JP": lambda: national_standard("euc_jp") | KANA | PUNCTUATION,
    # Korean: KS X 1001, which carries both hangul syllables and the hanja that
    # Korean philosophical texts are written in.
    "KR": lambda: national_standard("euc_kr") | PUNCTUATION,
}


def main() -> int:
    if not OUT_DIR.parent.exists():
        print("run this from the repository root", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for region, charset in REGIONS.items():
            source = work / f"NotoSerif{region}.otf"
            print(f"downloading {region}…", flush=True)
            urllib.request.urlretrieve(UPSTREAM.format(region=region), source)

            characters = sorted(charset())
            text_file = work / f"chars_{region}.txt"
            text_file.write_text("".join(characters), encoding="utf-8")

            target = OUT_DIR / f"NotoSerif{region}-Subset.ttf"
            print(f"subsetting {region} to {len(characters)} characters…")
            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "fontTools.subset",
                    str(source),
                    f"--text-file={text_file}",
                    f"--output-file={target}",
                    "--no-hinting",
                    "--desubroutinize",
                    "--layout-features=",
                    "--name-IDs=*",
                    "--notdef-outline",
                    "--drop-tables+=DSIG",
                ],
                check=True,
            )
            size_mb = target.stat().st_size / 1_000_000
            print(f"  → {target} ({size_mb:.1f} MB)")

        # The OFL requires the licence to travel with the fonts.
        urllib.request.urlretrieve(LICENSE_URL, OUT_DIR / "OFL.txt")

    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
