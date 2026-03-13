#!/usr/bin/env python3
"""
fix_tafsir_boundaries.py — Remove cross-surah boundary duplications in tafsir data.

Some tafsir editions have a digitization bug where the last verse of surah N is
duplicated as verse 1 of surah N+1. This script detects and removes those entries.
"""

import json
import os

EDITIONS = ["ibn_kathir", "maarif_ul_quran", "ibn_abbas", "tazkirul_quran"]
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "Niya", "Resources", "Data")


def fix_edition(edition: str) -> list[tuple[int, int]]:
    """Fix boundary duplications for one edition. Returns list of (surahN, surahN+1) pairs fixed."""
    edition_dir = os.path.join(DATA_DIR, f"tafsir_{edition}")
    if not os.path.isdir(edition_dir):
        print(f"  SKIP {edition}: directory not found")
        return []

    fixes = []
    for surah_n in range(1, 114):
        surah_next = surah_n + 1
        path_n = os.path.join(edition_dir, f"{surah_n}.json")
        path_next = os.path.join(edition_dir, f"{surah_next}.json")

        if not os.path.isfile(path_n) or not os.path.isfile(path_next):
            continue

        with open(path_n, encoding="utf-8") as f:
            data_n = json.load(f)
        with open(path_next, encoding="utf-8") as f:
            data_next = json.load(f)

        if "1" not in data_next:
            continue

        # Find last verse key in surah N
        int_keys = [int(k) for k in data_n]
        if not int_keys:
            continue
        last_key = str(max(int_keys))

        if data_n[last_key] == data_next["1"]:
            del data_next["1"]
            with open(path_next, "w", encoding="utf-8") as f:
                json.dump(data_next, f, ensure_ascii=False)
            fixes.append((surah_n, surah_next))

    return fixes


def main():
    total = 0
    for edition in EDITIONS:
        print(f"Checking {edition}...")
        fixes = fix_edition(edition)
        if fixes:
            for surah_n, surah_next in fixes:
                print(f"  Removed surah {surah_next} verse 1 (duplicate of surah {surah_n} last verse)")
            total += len(fixes)
        else:
            print(f"  No boundary duplications found")

    print(f"\nTotal: {total} entries removed")


if __name__ == "__main__":
    main()
