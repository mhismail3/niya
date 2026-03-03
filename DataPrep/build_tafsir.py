#!/usr/bin/env python3
"""
Build bundled tafsir JSON files from spa5k/tafsir_api repo data.

Input:  /tmp/tafsir_api_extract/tafsir_api-main/tafsir/<edition>/<surah>/<ayah>.json
Output: Niya/Resources/Data/tafsir_<key>.json  (one file per edition)

Each output file is a dict keyed by "surahId:ayahId" → text string.
Empty-text entries are omitted to save space.

Usage:
    # First download and extract the repo:
    curl -sL https://github.com/spa5k/tafsir_api/archive/refs/heads/main.zip -o /tmp/tafsir_api.zip
    cd /tmp && unzip -q -o tafsir_api.zip -d tafsir_api_extract

    # Then run:
    python3 DataPrep/build_tafsir.py
"""

import json
import os
import sys

REPO_BASE = "/tmp/tafsir_api_extract/tafsir_api-main/tafsir"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Niya", "Resources", "Data")

EDITIONS = {
    "ibn_kathir": "en-tafisr-ibn-kathir",
    "maarif_ul_quran": "en-tafsir-maarif-ul-quran",
    "ibn_abbas": "en-tafsir-ibn-abbas",
    "tazkirul_quran": "en-tazkirul-quran",
}

SURAH_VERSE_COUNTS = {
    1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75,
    9: 129, 10: 109, 11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128,
    17: 111, 18: 110, 19: 98, 20: 135, 21: 112, 22: 78, 23: 118, 24: 64,
    25: 77, 26: 227, 27: 93, 28: 88, 29: 69, 30: 60, 31: 34, 32: 30,
    33: 73, 34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
    41: 54, 42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29,
    49: 18, 50: 45, 51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96,
    57: 29, 58: 22, 59: 24, 60: 13, 61: 14, 62: 11, 63: 11, 64: 18,
    65: 12, 66: 12, 67: 30, 68: 52, 69: 52, 70: 44, 71: 28, 72: 28,
    73: 20, 74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
    81: 29, 82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26,
    89: 30, 90: 20, 91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19,
    97: 5, 98: 8, 99: 8, 100: 11, 101: 11, 102: 8, 103: 3, 104: 9,
    105: 5, 106: 4, 107: 7, 108: 3, 109: 6, 110: 3, 111: 5, 112: 4,
    113: 5, 114: 6,
}


def build_edition(key: str, slug: str) -> dict:
    """Read all per-verse JSON files for one edition, return {surah:ayah -> text}."""
    edition_dir = os.path.join(REPO_BASE, slug)
    if not os.path.isdir(edition_dir):
        print(f"  WARNING: directory not found: {edition_dir}")
        return {}

    result = {}
    missing = 0
    empty = 0
    for surah_id, verse_count in SURAH_VERSE_COUNTS.items():
        for ayah_id in range(1, verse_count + 1):
            fpath = os.path.join(edition_dir, str(surah_id), f"{ayah_id}.json")
            if not os.path.isfile(fpath):
                missing += 1
                continue
            with open(fpath, encoding="utf-8") as f:
                data = json.load(f)
            text = data.get("text", "").strip()
            if not text:
                empty += 1
                continue
            result[f"{surah_id}:{ayah_id}"] = text

    print(f"  {len(result)} entries, {missing} missing files, {empty} empty texts")
    return result


def main():
    if not os.path.isdir(REPO_BASE):
        print(f"ERROR: Repo not found at {REPO_BASE}")
        print("Download it first:")
        print("  curl -sL https://github.com/spa5k/tafsir_api/archive/refs/heads/main.zip -o /tmp/tafsir_api.zip")
        print("  cd /tmp && unzip -q -o tafsir_api.zip -d tafsir_api_extract")
        sys.exit(1)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for key, slug in EDITIONS.items():
        print(f"Building tafsir_{key}.json from {slug}...")
        data = build_edition(key, slug)
        if not data:
            print(f"  SKIPPED (no data)")
            continue

        outpath = os.path.join(OUTPUT_DIR, f"tafsir_{key}.json")
        with open(outpath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        size_mb = os.path.getsize(outpath) / (1024 * 1024)
        print(f"  Written: {outpath} ({size_mb:.1f} MB)")

    print("\nDone!")


if __name__ == "__main__":
    main()
