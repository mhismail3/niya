#!/usr/bin/env python3
"""
split_tafsir.py — Split monolithic tafsir JSON files into per-surah files.

Input:  Niya/Resources/Data/tafsir_{edition}.json  (keyed by "surahId:ayahId")
Output: Niya/Resources/Data/tafsir_{edition}/{surahId}.json (keyed by ayahId only)
"""

import json
import os

EDITIONS = ["ibn_kathir", "maarif_ul_quran", "ibn_abbas", "tazkirul_quran"]
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "Niya", "Resources", "Data")


def split_edition(edition: str):
    src = os.path.join(DATA_DIR, f"tafsir_{edition}.json")
    if not os.path.exists(src):
        print(f"  SKIP {edition}: {src} not found")
        return

    with open(src, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Group by surah
    by_surah: dict[int, dict[str, str]] = {}
    for key, text in data.items():
        parts = key.split(":")
        if len(parts) != 2:
            continue
        surah_id = int(parts[0])
        ayah_id = parts[1]
        if surah_id not in by_surah:
            by_surah[surah_id] = {}
        by_surah[surah_id][ayah_id] = text

    # Write per-surah files
    out_dir = os.path.join(DATA_DIR, f"tafsir_{edition}")
    os.makedirs(out_dir, exist_ok=True)

    for surah_id in sorted(by_surah.keys()):
        out_path = os.path.join(out_dir, f"{surah_id}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(by_surah[surah_id], f, ensure_ascii=False)

    total_surahs = len(by_surah)
    total_entries = sum(len(v) for v in by_surah.values())
    print(f"  {edition}: {total_entries} entries -> {total_surahs} surah files")


def main():
    print("Splitting tafsir files...")
    for edition in EDITIONS:
        split_edition(edition)
    print("Done.")


if __name__ == "__main__":
    main()
