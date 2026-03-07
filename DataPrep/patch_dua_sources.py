#!/usr/bin/env python3
"""
patch_dua_sources.py — Apply hadith references to all duas in dua_all.json

Reads:
  - Niya/Resources/Data/dua_all.json (current data)
  - DataPrep/source/dua/hisn_references.json (scraped from sunnah.com, IDs 1-267)
  - DataPrep/source/dua/fitrahive_references.json (manually researched, IDs 268+)

Actions:
  1. Add sources to Hisn entries (IDs 1-267) from sunnah.com references
  2. Add sources to fitrahive entries from researched references
  3. Remove duplicate/non-dua fitrahive entries
  4. Fix category totalDuas counts, remove empty categories
  5. Validate: assert every remaining dua has a non-empty source

Output: Niya/Resources/Data/dua_all.json (overwritten)
"""

import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DUA_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "dua_all.json")
HISN_REFS_PATH = os.path.join(SCRIPT_DIR, "source", "dua", "hisn_references.json")
FITRA_REFS_PATH = os.path.join(SCRIPT_DIR, "source", "dua", "fitrahive_references.json")


def main():
    # Load all data
    with open(DUA_PATH, encoding="utf-8") as f:
        data = json.load(f)

    with open(HISN_REFS_PATH, encoding="utf-8") as f:
        hisn_refs = json.load(f)

    with open(FITRA_REFS_PATH, encoding="utf-8") as f:
        fitra_data = json.load(f)

    fitra_sources = fitra_data["sources"]
    fitra_remove = set(int(k) for k in fitra_data["remove"].keys())

    sections = data["sections"]
    categories = data["categories"]
    duas = data["duas"]

    # Step 1: Apply Hisn references (IDs 1-267)
    hisn_applied = 0
    for cat_id, dua_list in duas.items():
        for dua in dua_list:
            if dua["id"] <= 267 and not dua.get("source"):
                ref = hisn_refs.get(str(dua["id"]))
                if ref:
                    dua["source"] = ref
                    hisn_applied += 1

    print(f"Applied {hisn_applied} Hisn references")

    # Step 2: Apply fitrahive references (IDs 268+)
    fitra_applied = 0
    for cat_id, dua_list in duas.items():
        for dua in dua_list:
            if dua["id"] >= 268 and not dua.get("source"):
                ref = fitra_sources.get(str(dua["id"]))
                if ref:
                    dua["source"] = ref
                    fitra_applied += 1

    print(f"Applied {fitra_applied} fitrahive references")

    # Step 3: Remove duplicate/non-dua entries
    removed_count = 0
    empty_cats = set()
    for cat_id in list(duas.keys()):
        original_len = len(duas[cat_id])
        duas[cat_id] = [d for d in duas[cat_id] if d["id"] not in fitra_remove]
        removed_count += original_len - len(duas[cat_id])
        if not duas[cat_id]:
            empty_cats.add(int(cat_id))
            del duas[cat_id]

    print(f"Removed {removed_count} duplicate/non-dua entries")
    if empty_cats:
        print(f"  Empty categories removed: {sorted(empty_cats)}")

    # Step 4: Fix category totalDuas counts and remove empty categories
    categories = [c for c in categories if c["id"] not in empty_cats]
    for cat in categories:
        cat_id = str(cat["id"])
        if cat_id in duas:
            cat["totalDuas"] = len(duas[cat_id])

    # Remove empty category IDs from sections
    for section in sections:
        section["categoryIds"] = [
            cid for cid in section["categoryIds"] if cid not in empty_cats
        ]
    # Remove sections with no categories
    sections = [s for s in sections if s["categoryIds"]]

    # Step 5: Validate — every dua must have a source
    missing = []
    total = 0
    for cat_id, dua_list in duas.items():
        for dua in dua_list:
            total += 1
            if not dua.get("source"):
                missing.append(dua["id"])

    if missing:
        print(f"\nWARNING: {len(missing)} duas still missing sources: {sorted(missing)}")
        sys.exit(1)
    else:
        print(f"\nValidation passed: all {total} duas have sources")

    # Write output
    output = {
        "sections": sections,
        "categories": sorted(categories, key=lambda c: c["id"]),
        "duas": duas,
    }
    with open(DUA_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(DUA_PATH) / 1024
    print(f"\nWritten: {DUA_PATH}")
    print(f"  {len(sections)} sections, {len(categories)} categories, {total} duas")
    print(f"  Size: {size_kb:.0f} KB")


if __name__ == "__main__":
    main()
