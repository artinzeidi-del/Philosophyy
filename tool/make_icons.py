#!/usr/bin/env python3
"""Render every launcher icon on every platform from assets/brand/logo.svg.

One source, generated outputs. Icons edited by hand are how a product ends up
with five slightly different marks — a rounded corner on Android, an older
version on the web, a stale 1024 in the App Store — and nothing notices,
because no two of them are ever on screen at the same time.

Three shapes come out of the one file:

  full bleed    the mark on its background, edge to edge. Legacy Android
                launchers, iOS (which applies its own mask), and the web.
  adaptive      the mark alone on transparency, scaled to Android's guaranteed
                safe zone: a circle 66dp across on a 108dp canvas. Anything
                outside it is at the launcher's mercy, and round masks are
                common enough that the tail would be the part it ate.
  maskable      the web equivalent, whose safe zone is more generous.

Usage:  python3 tool/make_icons.py
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets/brand/logo.svg'
RENDER = ROOT / 'tool/render_svg.mjs'
TMP = ROOT / '.icon-build'

# The mark's bounding box inside the 1024 canvas, measured from the geometry in
# logo.svg: the tail's rounded cap on the left, the bowl on the right, the
# diamond's top point, the ring's bottom. Recompute these if the mark moves.
BBOX = (202, 131, 754, 800)
CANVAS = 1024

# Android guarantees only the inner 66 of 108. The web's maskable spec is
# kinder at 80 of 100.
ANDROID_SAFE = 66 / 108
WEB_SAFE = 0.80

ANDROID_LEGACY = {
    'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
}
# Adaptive layers are 108dp, so each density's pixel size is 108/48 of legacy.
ANDROID_ADAPTIVE = {name: round(size * 108 / 48) for name, size in ANDROID_LEGACY.items()}

IOS = {
    'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60, 'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120, 'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180, 'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152, 'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}


def background_colour() -> str:
    """The fill of the source's backing rectangle."""
    for line in SOURCE.read_text(encoding='utf-8').splitlines():
        if '<rect width="1024" height="1024"' in line:
            return line.split('fill="')[1].split('"')[0]
    raise SystemExit('logo.svg has no full-canvas background rectangle')


def inset_svg(safe: float, keep_background: bool) -> str:
    """The source with its mark scaled to fit `safe`, as a fraction of the canvas.

    The mark is scaled about its own bounding-box centre and re-centred on the
    canvas, so a tall mark and a wide one are both held to the same circle.
    """
    left, top, right, bottom = BBOX
    width, height = right - left, bottom - top
    diagonal = (width ** 2 + height ** 2) ** 0.5
    scale = min(1.0, CANVAS * safe / diagonal)

    centre_x, centre_y = (left + right) / 2, (top + bottom) / 2
    dx = CANVAS / 2 - centre_x * scale
    dy = CANVAS / 2 - centre_y * scale

    source = SOURCE.read_text(encoding='utf-8')
    head, _, tail = source.partition('>')  # keep the opening <svg …> tag
    body = tail
    if not keep_background:
        body = '\n'.join(
            line for line in body.splitlines()
            if '<rect width="1024" height="1024"' not in line
        )
    body = body.replace('</svg>', '')
    return (
        f'{head}>\n<g transform="translate({dx:.2f} {dy:.2f}) '
        f'scale({scale:.4f})">{body}</g>\n</svg>'
    )


def render(svg_text: str, out: Path, size: int, transparent: bool = False) -> None:
    TMP.mkdir(exist_ok=True)
    scratch = TMP / 'render.svg'
    scratch.write_text(svg_text, encoding='utf-8')
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ['node', str(RENDER), str(scratch), str(out), str(size),
         'transparent' if transparent else 'opaque'],
        check=True, capture_output=True,
    )


def main() -> int:
    if not SOURCE.exists():
        raise SystemExit(f'{SOURCE} is missing')

    full = SOURCE.read_text(encoding='utf-8')
    adaptive = inset_svg(ANDROID_SAFE, keep_background=False)
    maskable = inset_svg(WEB_SAFE, keep_background=True)
    written = 0

    for density, size in ANDROID_LEGACY.items():
        render(full, ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
        written += 1
    for density, size in ANDROID_ADAPTIVE.items():
        render(
            adaptive,
            ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png',
            size, transparent=True,
        )
        written += 1

    colour = background_colour()
    (ROOT / 'android/app/src/main/res/values').mkdir(parents=True, exist_ok=True)
    (ROOT / 'android/app/src/main/res/values/ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        f'    <color name="ic_launcher_background">{colour}</color>\n'
        '</resources>\n', encoding='utf-8')

    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    anydpi = ROOT / 'android/app/src/main/res/mipmap-anydpi-v26'
    anydpi.mkdir(parents=True, exist_ok=True)
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        (anydpi / name).write_text(adaptive_xml, encoding='utf-8')
        written += 1

    for name, size in IOS.items():
        render(full, ROOT / f'ios/Runner/Assets.xcassets/AppIcon.appiconset/{name}', size)
        written += 1

    for name, size, svg in (
        ('Icon-192.png', 192, full), ('Icon-512.png', 512, full),
        ('Icon-maskable-192.png', 192, maskable),
        ('Icon-maskable-512.png', 512, maskable),
    ):
        render(svg, ROOT / f'web/icons/{name}', size)
        written += 1
    render(full, ROOT / 'web/favicon.png', 32)
    written += 1

    for scratch in TMP.glob('*'):
        scratch.unlink()
    TMP.rmdir()
    print(f'{written} icons written from {SOURCE.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
