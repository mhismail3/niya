#!/usr/bin/env python3
"""Validate IndoPak source data before build."""
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_PATH = os.path.join(SCRIPT_DIR, "source", "quran_indopak.json")
HAFS_PATH = os.path.join(SCRIPT_DIR, "source", "chapters_en")

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

ARABIC_PATTERN = re.compile(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]')

errors = []

def fail(msg):
    errors.append(msg)
    print(f"  FAIL: {msg}")

def check():
    print(f"Loading {SOURCE_PATH}")
    if not os.path.exists(SOURCE_PATH):
        fail(f"File not found: {SOURCE_PATH}")
        return

    with open(SOURCE_PATH, 'r', encoding='utf-8') as f:
        raw = f.read()

    # BOM check
    if raw.startswith('\ufeff'):
        fail("File starts with UTF-8 BOM")

    data = json.loads(raw)

    # All 114 surahs present
    print("Checking surah count...")
    if len(data) != 114:
        fail(f"Expected 114 surahs, got {len(data)}")
    for sid in range(1, 115):
        if str(sid) not in data:
            fail(f"Missing surah {sid}")

    # Correct verse counts
    print("Checking verse counts...")
    total = 0
    for sid in range(1, 115):
        key = str(sid)
        if key not in data:
            continue
        verses = data[key]
        expected = EXPECTED_VERSE_COUNTS[sid]
        actual = len(verses)
        total += actual
        if actual != expected:
            fail(f"Surah {sid}: expected {expected} verses, got {actual}")

    if total != 6236:
        fail(f"Total verses: expected 6236, got {total}")
    else:
        print(f"  OK: {total} total verses")

    # No empty text, valid UTF-8, Arabic characters
    print("Checking verse text quality...")
    empty_count = 0
    no_arabic_count = 0
    for sid in range(1, 115):
        key = str(sid)
        if key not in data:
            continue
        for aid_key, text in data[key].items():
            if not text or not text.strip():
                empty_count += 1
                fail(f"Surah {sid} ayah {aid_key}: empty text")
            elif not ARABIC_PATTERN.search(text):
                no_arabic_count += 1
                fail(f"Surah {sid} ayah {aid_key}: no Arabic characters")

    if empty_count == 0:
        print("  OK: no empty verses")
    if no_arabic_count == 0:
        print("  OK: all verses contain Arabic characters")

    # Spot-check known verses
    print("Spot-checking known verses...")
    v1_1 = data.get("1", {}).get("1", "")
    # Check for base consonants ب س م (may have diacritics between them in IndoPak)
    base_letters = [c for c in v1_1 if '\u0621' <= c <= '\u064A' or '\u0671' <= c <= '\u06D3']
    if len(base_letters) < 3 or base_letters[0] != 'ب' or base_letters[1] != 'س' or base_letters[2] != 'م':
        fail(f"1:1 doesn't start with ب-س-م base letters: {v1_1[:50]}")
    else:
        print("  OK: 1:1 starts with بسم")

    # Compare against Hafs — text should differ
    print("Comparing against Hafs text...")
    if os.path.exists(HAFS_PATH):
        differ_count = 0
        total_compared = 0
        for sid in range(1, 115):
            ch_path = os.path.join(HAFS_PATH, f"{sid}.json")
            if not os.path.exists(ch_path):
                continue
            with open(ch_path, 'r', encoding='utf-8') as f:
                ch = json.load(f)
            ip_surah = data.get(str(sid), {})
            for v in ch.get("verses", []):
                aid = str(v["id"])
                hafs_text = v["text"]
                ip_text = ip_surah.get(aid, "")
                total_compared += 1
                if ip_text != hafs_text:
                    differ_count += 1
        if total_compared > 0:
            pct = differ_count / total_compared * 100
            print(f"  {differ_count}/{total_compared} verses differ ({pct:.1f}%)")
            if pct < 90:
                fail(f"Only {pct:.1f}% of verses differ from Hafs (expected >90%)")
        else:
            print("  SKIP: no Hafs data to compare")
    else:
        print("  SKIP: chapters_en not found")

    return len(errors) == 0

if __name__ == "__main__":
    print("=== IndoPak Data Validation ===\n")
    ok = check()
    print(f"\n{'PASS' if ok else 'FAIL'}: {len(errors)} error(s)")
    sys.exit(0 if ok else 1)
