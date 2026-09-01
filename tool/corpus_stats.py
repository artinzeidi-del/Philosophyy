#!/usr/bin/env python3
"""Counts what is in assets/content, so the figures in the docs can be checked.

Every number quoted in README.md and docs/STATUS.md comes from here. They were
hand-maintained before, and drifted: the README claimed 256 quotations against
a file holding 238, and 191 philosophers after a hundred and ninety-second was
added. A number nobody can reproduce is a number nobody can correct.

A word is a run of characters between spaces, which is the ordinary sense in
both languages — Persian compounds joined by a zero-width non-joiner count as
one word, as they are read. Reading speed is 200 English words a minute and
150 Persian, the slower figure because the script is denser and this is
reference prose rather than a novel.
"""

import json
import pathlib
import sys

CONTENT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'content'

COLLECTIONS = {
    'philosophers': 'philosophers',
    'concepts': 'concepts',
    'works': 'works',
    'schools': 'schools',
    'quotes': 'quotes',
    'arguments': 'arguments',
    'problems': 'problems',
    'sources': 'sources',
    'glossary': 'terms',
    'relations': 'relations',
    'primer': 'steps',
    'taxonomy': 'terms',
}

ENTITY_FILES = ('philosophers', 'concepts', 'works', 'schools')


def load(name):
    with open(CONTENT / f'{name}.json', encoding='utf-8') as handle:
        return json.load(handle)[COLLECTIONS[name]]


def words(text):
    return len(text.split())


def count_prose(node, totals):
    """Adds every localised string reachable from node to the totals."""
    if isinstance(node, dict):
        for language in ('en', 'fa'):
            value = node.get(language)
            if isinstance(value, str):
                totals[language] += words(value)
        for value in node.values():
            count_prose(value, totals)
    elif isinstance(node, list):
        for value in node:
            count_prose(value, totals)


def main():
    counts = {name: len(load(name)) for name in COLLECTIONS}

    entities = [item for name in ENTITY_FILES for item in load(name)]
    sections = 0
    depths_complete = 0
    for entity in entities:
        article = entity.get('article') or {}
        found = article.get('sections') or []
        sections += len(found)
        if {'quick', 'standard', 'deep'} <= {s.get('depth') for s in found}:
            depths_complete += 1

    totals = {'en': 0, 'fa': 0}
    for name in COLLECTIONS:
        count_prose(load(name), totals)

    print('Entries')
    for name in COLLECTIONS:
        print(f'  {name:<14} {counts[name]:>5}')
    print()
    print(f'  entities       {len(entities):>5}  (the four kinds that carry articles)')
    print(f'  screens        {len(entities) * 2:>5}  (each entity in each language)')
    print(f'  sections       {sections:>5}')
    print(f'  all three depths {depths_complete:>3} of {len(entities)}')
    print()
    print('Prose')
    print(f'  English        {totals["en"]:>7,} words   {totals["en"] / 200 / 60:>5.1f} hours')
    print(f'  Persian        {totals["fa"]:>7,} words   {totals["fa"] / 150 / 60:>5.1f} hours')
    return 0


if __name__ == '__main__':
    sys.exit(main())
