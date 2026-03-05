#!/usr/bin/env python3
"""
Fetch authentic IndoPak Quran text from Quran.com API v4.

Uses the text_indopak field which provides genuine IndoPak/Nastaleeq script text,
verified against King Fahad Complex Nastaleeq Mushaf.

Output: DataPrep/source/quran_indopak.json — dict of {surahId: {ayahId: text}}

Usage:
    python3 DataPrep/fetch_indopak.py
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "source", "quran_indopak.json")

API_BASE = "https://api.quran.com/api/v4/quran/verses/indopak"
RATE_LIMIT = 0.5
MAX_RETRIES = 3
RETRY_BACKOFF = 2.0
REQUEST_TIMEOUT = 30

EXPECTED_VERSE_COUNTS = {
    1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75, 9: 129, 10: 109,
    11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128, 17: 111, 18: 110, 19: 98, 20: 135,
    21: 112, 22: 78, 23: 118, 24: 64, 25: 77, 26: 227, 27: 93, 28: 88, 29: 69, 30: 60,
    31: 34, 32: 30, 33: 73, 34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
    41: 54, 42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29, 49: 18, 50: 45,
    51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96, 57: 29, 58: 22, 59: 24, 60: 13,
    61: 14, 62: 11, 63: 11, 64: 18, 65: 12, 66: 12, 67: 30, 68: 52, 69: 52, 70: 44,
    71: 28, 72: 28, 73: 20, 74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
    81: 29, 82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26, 89: 30, 90: 20,
    91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19, 97: 5, 98: 8, 99: 8, 100: 11,
    101: 11, 102: 8, 103: 3, 104: 9, 105: 5, 106: 4, 107: 7, 108: 3, 109: 6, 110: 3,
    111: 5, 112: 4, 113: 5, 114: 6,
}


def fetch_url(url, retries=MAX_RETRIES):
    """Fetch URL with retries and backoff."""
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Niya-DataPrep/1.0"})
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError) as e:
            if attempt < retries - 1:
                wait = RETRY_BACKOFF * (attempt + 1)
                print(f"  Retry {attempt+1}/{retries} after {wait}s: {e}")
                time.sleep(wait)
            else:
                raise


def fetch_chapter(chapter_id):
    """Fetch IndoPak text for a single chapter."""
    url = f"{API_BASE}?chapter_number={chapter_id}"
    data = fetch_url(url)
    verses = {}
    for v in data.get("verses", []):
        verse_key = v.get("verse_key", "")
        parts = verse_key.split(":")
        if len(parts) == 2:
            ayah_id = parts[1]
            text = v.get("text_indopak", "")
            if text:
                # Strip BOM if present
                text = text.lstrip('\ufeff')
                verses[ayah_id] = text
    return verses


def main():
    print("=== Fetching IndoPak Text from Quran.com API v4 ===\n")

    result = {}
    total_verses = 0

    for sid in range(1, 115):
        expected = EXPECTED_VERSE_COUNTS[sid]
        print(f"Surah {sid}/114 (expecting {expected} verses)...", end=" ", flush=True)

        verses = fetch_chapter(sid)
        actual = len(verses)
        total_verses += actual

        if actual != expected:
            print(f"WARNING: got {actual} verses (expected {expected})")
        else:
            print(f"OK ({actual} verses)")

        result[str(sid)] = verses
        time.sleep(RATE_LIMIT)

    print(f"\nTotal verses fetched: {total_verses}")
    if total_verses != 6236:
        print(f"WARNING: Expected 6236, got {total_verses}")

    # Write output
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    size_kb = os.path.getsize(OUTPUT_PATH) // 1024
    print(f"\nWritten to {OUTPUT_PATH} ({size_kb}KB)")
    print("Done!")


if __name__ == "__main__":
    main()
