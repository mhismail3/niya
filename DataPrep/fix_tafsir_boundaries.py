#!/usr/bin/env python3
"""
fix_tafsir_boundaries.py — Remove cross-surah boundary contamination in tafsir data.

Due to a digitization bug in quran.com's verse-to-commentary-block mapping,
the first N verses of some surahs contain commentary from the previous surah.
This happens because these tafsirs cover verse groups, and the group boundaries
were shifted by one at surah boundaries. The real commentary for those verses
was never entered into the database.

This script detects contaminated verses by checking if text in surah N+1 matches
any text in surah N, then removes them. It processes all consecutive contaminated
verses from the start of each affected surah (not just verse 1).
"""

import json
import os
import re

EDITIONS = ["ibn_kathir", "maarif_ul_quran", "ibn_abbas", "tazkirul_quran"]
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "Niya", "Resources", "Data")

# Arabic Ibn Kathir source for surah 105 (English version is missing from upstream)
AR_IBN_KATHIR_UPSTREAM = "/tmp/tafsir_api_extract/tafsir_api-main/tafsir/ar-tafsir-ibn-kathir"


def fix_edition(edition: str) -> list[tuple[int, list[int]]]:
    """Fix boundary contamination for one edition.

    Returns list of (surah, [removed_ayahs]) tuples.
    """
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

        prev_texts = set(data_n.values())
        removed = []

        # Remove consecutive contaminated verses from the start
        ayah = 1
        while str(ayah) in data_next and data_next[str(ayah)] in prev_texts:
            del data_next[str(ayah)]
            removed.append(ayah)
            ayah += 1

        if removed:
            with open(path_next, "w", encoding="utf-8") as f:
                json.dump(data_next, f, ensure_ascii=False)
            fixes.append((surah_next, removed))

    return fixes


def patch_ibn_kathir_105():
    """Replace Ibn Kathir surah 105 with Arabic source text.

    The English abridged Ibn Kathir has no valid data for surah 105 (Al-Fil) —
    the upstream source is entirely corrupted. Use Arabic Ibn Kathir instead.
    """
    out_path = os.path.join(DATA_DIR, "tafsir_ibn_kathir", "105.json")
    ar_dir = AR_IBN_KATHIR_UPSTREAM

    if not os.path.isdir(os.path.join(ar_dir, "105")):
        print("  WARNING: Arabic Ibn Kathir source not available for surah 105 patch")
        return False

    new_data = {}
    for i in range(1, 6):
        with open(os.path.join(ar_dir, "105", f"{i}.json")) as f:
            d = json.load(f)
        text = d.get("text", "")
        clean = re.sub(r'<[^>]+>', '', text).strip()
        clean = re.sub(r'\n\s*\n', '\n\n', clean)
        if clean:
            new_data[str(i)] = clean

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(new_data, f, ensure_ascii=False)

    print(f"  Patched surah 105 with Arabic Ibn Kathir ({len(new_data)} verses)")
    return True


def main():
    total_verses = 0
    total_surahs = 0

    for edition in EDITIONS:
        print(f"Checking {edition}...")
        fixes = fix_edition(edition)
        if fixes:
            for surah, removed in fixes:
                ayah_range = f"{removed[0]}-{removed[-1]}" if len(removed) > 1 else str(removed[0])
                print(f"  Surah {surah}: removed ayahs {ayah_range} ({len(removed)} verses)")
                total_verses += len(removed)
                total_surahs += 1
        else:
            print(f"  No contamination found")

    # Special case: Ibn Kathir 105 needs Arabic source replacement
    # (all 5 English verses were wrong, leaving it empty after cleanup)
    ibn_kathir_105 = os.path.join(DATA_DIR, "tafsir_ibn_kathir", "105.json")
    with open(ibn_kathir_105) as f:
        d = json.load(f)
    if not d:
        print("\nIbn Kathir surah 105 is empty after cleanup — patching with Arabic source...")
        patch_ibn_kathir_105()

    print(f"\nTotal: {total_verses} verses removed across {total_surahs} surahs")


if __name__ == "__main__":
    main()
