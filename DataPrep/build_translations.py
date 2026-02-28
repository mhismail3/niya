#!/usr/bin/env python3
"""Validate and copy translation files to Niya/Resources/Data/."""
import json
import os
import shutil

SCRIPT_DIR = os.path.dirname(__file__)
INPUT_DIR = os.path.join(SCRIPT_DIR, "output", "translations")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "Niya", "Resources", "Data")

EXPECTED_VERSES = 6236

def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

# Load index
index_path = os.path.join(INPUT_DIR, "translations_index.json")
if not os.path.exists(index_path):
    print("ERROR: translations_index.json not found. Run fetch_translations.py first.")
    exit(1)

index = load_json(index_path)
print(f"Index has {len(index)} translations\n")

errors = 0
for entry in index:
    tid = entry["id"]
    filename = entry["filename"]
    src = os.path.join(INPUT_DIR, filename)

    if not os.path.exists(src):
        print(f"  MISSING: {filename}")
        errors += 1
        continue

    overlay = load_json(src)
    count = len(overlay)
    empty = sum(1 for v in overlay.values() if not v.strip())

    status = "OK"
    if count != EXPECTED_VERSES:
        status = f"WRONG COUNT ({count})"
        errors += 1
    if empty > 0:
        status = f"EMPTY ({empty} blank)"
        errors += 1

    size_kb = os.path.getsize(src) / 1024
    print(f"  {tid:20s}  {count:5d} verses  {size_kb:7.1f} KB  {status}")

    # Copy to Resources
    dst = os.path.join(OUTPUT_DIR, filename)
    shutil.copy2(src, dst)

# Copy index
shutil.copy2(index_path, os.path.join(OUTPUT_DIR, "translations_index.json"))

print(f"\nCopied {len(index)} translation files + index to {OUTPUT_DIR}")
if errors:
    print(f"WARNING: {errors} error(s) found!")
else:
    print("All validations passed.")
