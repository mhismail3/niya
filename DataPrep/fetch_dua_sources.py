#!/usr/bin/env python3
"""
fetch_dua_sources.py — Download external dua/azkar source data.

Downloads to DataPrep/source/dua/:
- azkar_db.json from osamayy/azkar-db (Arabic azkar with references)
- hisn_arabic.json from rn0x/hisn_almuslim_json (for citation enrichment)

Existing files (husn_en.json, fitrahive/) are left untouched.
Idempotent: skips existing files unless --force is passed.
"""

import json
import os
import sys
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIR = os.path.join(SCRIPT_DIR, "source", "dua")

SOURCES = {
    "azkar_db.json": "https://raw.githubusercontent.com/osamayy/azkar-db/master/azkar.json",
    "hisn_arabic.json": "https://raw.githubusercontent.com/rn0x/hisn_almuslim_json/main/hisn_almuslim.json",
}


def download(url, dest_path):
    print(f"  Downloading {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "Niya-DataPrep/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    with open(dest_path, "wb") as f:
        f.write(data)
    size_kb = len(data) / 1024
    print(f"  Saved {dest_path} ({size_kb:.0f} KB)")


def main():
    force = "--force" in sys.argv

    os.makedirs(SOURCE_DIR, exist_ok=True)

    for filename, url in SOURCES.items():
        dest = os.path.join(SOURCE_DIR, filename)
        if os.path.exists(dest) and not force:
            print(f"  Skipping {filename} (exists, use --force to re-download)")
            continue
        try:
            download(url, dest)
        except Exception as e:
            print(f"  ERROR downloading {filename}: {e}")
            sys.exit(1)

    # Validate downloads are valid JSON
    for filename in SOURCES:
        path = os.path.join(SOURCE_DIR, filename)
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                try:
                    data = json.load(f)
                    if isinstance(data, list):
                        print(f"  {filename}: {len(data)} entries")
                    elif isinstance(data, dict):
                        print(f"  {filename}: {len(data)} top-level keys")
                except json.JSONDecodeError as e:
                    print(f"  ERROR: {filename} is not valid JSON: {e}")
                    sys.exit(1)

    print("\nDone. Source files ready in DataPrep/source/dua/")


if __name__ == "__main__":
    main()
