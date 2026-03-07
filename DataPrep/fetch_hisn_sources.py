#!/usr/bin/env python3
"""
fetch_hisn_sources.py — Scrape hadith references for all 267 Hisn al-Muslim entries from sunnah.com

Each page at sunnah.com/hisn:{id} has a <span class="hisn_english_reference"> with the reference text.
IDs 1-267 map 1:1 with our husn_en.json entries.

Output: DataPrep/source/dua/hisn_references.json
"""

import json
import os
import re
import time
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "source", "dua", "hisn_references.json")

TOTAL_ENTRIES = 267
DELAY = 0.5  # seconds between requests
REF_PATTERN = re.compile(
    r'class="hisn_english_reference"[^>]*>(.*?)</span>', re.DOTALL
)


def fetch_reference(hisn_id):
    """Fetch the reference text for a single Hisn al-Muslim entry."""
    url = f"https://sunnah.com/hisn:{hisn_id}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    resp = urllib.request.urlopen(req, timeout=15)
    html = resp.read().decode("utf-8")

    matches = REF_PATTERN.findall(html)
    if not matches:
        return None

    # Clean up whitespace
    text = matches[0].strip()
    text = re.sub(r"\s+", " ", text)
    return text


def main():
    # Resume from existing file if present
    if os.path.exists(OUTPUT_PATH):
        with open(OUTPUT_PATH, encoding="utf-8") as f:
            refs = json.load(f)
        print(f"Resuming: {len(refs)} already scraped")
    else:
        refs = {}

    missing = [i for i in range(1, TOTAL_ENTRIES + 1) if str(i) not in refs]
    if not missing:
        print(f"All {TOTAL_ENTRIES} references already scraped.")
        return

    print(f"Fetching {len(missing)} remaining references...")
    errors = []

    for idx, hisn_id in enumerate(missing):
        try:
            ref = fetch_reference(hisn_id)
            if ref:
                refs[str(hisn_id)] = ref
                status = f"OK ({len(ref)} chars)"
            else:
                status = "NO REFERENCE FOUND"
                errors.append(hisn_id)
        except Exception as e:
            status = f"ERROR: {e}"
            errors.append(hisn_id)

        print(f"  [{idx+1}/{len(missing)}] hisn:{hisn_id} — {status}")

        # Save progress every 25 entries
        if (idx + 1) % 25 == 0:
            os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
            with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
                json.dump(refs, f, ensure_ascii=False, indent=2)
            print(f"  (saved {len(refs)} refs)")

        time.sleep(DELAY)

    # Final save
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(refs, f, ensure_ascii=False, indent=2)

    print(f"\nDone: {len(refs)}/{TOTAL_ENTRIES} references saved to {OUTPUT_PATH}")
    if errors:
        print(f"Errors on IDs: {errors}")


if __name__ == "__main__":
    main()
