#!/usr/bin/env python3
"""
build_quranic_duas.py — Extract Quranic duas from verses_hafs.json.

Reads the curated mapping from source/dua/quranic_duas_mapping.json
and looks up each verse in Niya/Resources/Data/verses_hafs.json.

Output: DataPrep/source/dua/quranic_duas_extracted.json
"""

import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
MAPPING_PATH = os.path.join(SCRIPT_DIR, "source", "dua", "quranic_duas_mapping.json")
VERSES_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "verses_hafs.json")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "source", "dua", "quranic_duas_extracted.json")


def main():
    with open(MAPPING_PATH, encoding="utf-8") as f:
        mapping = json.load(f)

    with open(VERSES_PATH, encoding="utf-8") as f:
        verses = json.load(f)

    extracted = []

    for entry in mapping:
        surah = entry["surah"]
        category = entry["category"]
        note = entry.get("note", "")
        surah_data = verses.get(str(surah), [])

        # Build a lookup from ayah id to verse object
        verse_lookup = {}
        for v in surah_data:
            verse_lookup[v["id"]] = v

        # Single ayah or multi-ayah
        if "ayahs" in entry:
            ayah_ids = entry["ayahs"]
        else:
            ayah_ids = [entry["ayah"]]

        arabic_parts = []
        translation_parts = []
        transliteration_parts = []

        for aid in ayah_ids:
            v = verse_lookup.get(aid)
            if not v:
                print(f"  WARNING: verse {surah}:{aid} not found")
                continue
            arabic_parts.append(v["text"])
            translation_parts.append(v["translation"])
            if v.get("transliteration"):
                transliteration_parts.append(v["transliteration"])

        if not arabic_parts:
            print(f"  SKIPPED: no verses found for {surah}:{ayah_ids}")
            continue

        arabic = " ".join(arabic_parts)
        translation = " ".join(translation_parts)
        transliteration = " ".join(transliteration_parts) if transliteration_parts else None

        if len(ayah_ids) == 1:
            reference = f"Quran {surah}:{ayah_ids[0]}"
        else:
            reference = f"Quran {surah}:{ayah_ids[0]}-{ayah_ids[-1]}"

        result = {
            "surah": surah,
            "ayahs": ayah_ids,
            "category": category,
            "note": note,
            "arabic": arabic,
            "translation": translation,
            "reference": reference,
        }
        if transliteration:
            result["transliteration"] = transliteration

        extracted.append(result)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(extracted, f, ensure_ascii=False, indent=2)

    print(f"Extracted {len(extracted)} Quranic duas")
    print(f"  Rabbana: {sum(1 for e in extracted if e['category'] == 'rabbana')}")
    print(f"  Rabbi: {sum(1 for e in extracted if e['category'] == 'rabbi')}")
    print(f"  Other: {sum(1 for e in extracted if e['category'] not in ('rabbana', 'rabbi'))}")
    print(f"  Output: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
