#!/usr/bin/env python3
"""
Fetch per-word meanings from Quran.com API v4 for supported languages.

Produces Niya/Resources/Data/word_meanings_{lang}.json for ur, bn, tr, id.
Each file is a flat dict: {"surah:verse:position": "meaning text"}

Usage:
    python3 DataPrep/fetch_word_meanings.py
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SURAHS_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "surahs.json")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data")

LANGUAGES = ["ur", "bn", "tr", "id", "fa", "hi", "ta"]
WORDS_API = "https://api.quran.com/api/v4/verses/by_chapter/{ch}?language={lang}&words=true&word_fields=text_uthmani&per_page=300&page={page}"

RATE_LIMIT = 0.5
MAX_RETRIES = 3
RETRY_BACKOFF = 2.0
REQUEST_TIMEOUT = 30

EXPECTED_TOTAL_WORDS = 77429


def load_surahs():
    with open(SURAHS_PATH, "r", encoding="utf-8") as f:
        surahs = json.load(f)
    return {s["id"]: s for s in surahs}


def api_get(url, attempt=1):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Niya/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            raw = resp.read().decode("utf-8")
        return json.loads(raw)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError) as e:
        if attempt < MAX_RETRIES:
            wait = RETRY_BACKOFF * attempt
            print(f"    retry {attempt}/{MAX_RETRIES} after {wait}s -- {e}")
            time.sleep(wait)
            return api_get(url, attempt + 1)
        raise


def fetch_meanings_for_language(lang, surahs):
    """Fetch per-word meanings for a single language."""
    meanings = {}
    total_words = 0

    print(f"\nFetching {lang} meanings for all 114 surahs...")

    for ch in range(1, 115):
        surah = surahs[ch]
        print(f"  [{ch:>3}/114] {surah['transliteration']}", end="", flush=True)

        page = 1
        surah_words = 0
        while True:
            url = WORDS_API.format(ch=ch, lang=lang, page=page)
            data = api_get(url)
            verses = data.get("verses", [])

            for verse_data in verses:
                verse_key = verse_data.get("verse_key", "")
                if ":" not in verse_key:
                    continue
                verse_num = int(verse_key.split(":")[1])
                word_seq = 0
                for w in verse_data.get("words", []):
                    if w.get("char_type_name") != "word":
                        continue
                    word_seq += 1
                    translation = w.get("translation") or {}
                    text = translation.get("text", "")
                    if text:
                        key = f"{ch}:{verse_num}:{word_seq}"
                        meanings[key] = text
                        surah_words += 1

            next_page = data.get("pagination", {}).get("next_page")
            if next_page is None:
                break
            page = next_page
            time.sleep(RATE_LIMIT)

        total_words += surah_words
        print(f" ({surah_words} words)")
        time.sleep(RATE_LIMIT)

    print(f"\nTotal {lang}: {total_words} words")
    return meanings, total_words


def save_meanings(lang, meanings):
    output_path = os.path.join(OUTPUT_DIR, f"word_meanings_{lang}.json")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(meanings, f, ensure_ascii=False, separators=(",", ":"))
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"Saved: {output_path} ({size_mb:.1f} MB)")
    return output_path


def self_test(lang, meanings):
    """Validate the generated meanings."""
    print(f"\n{'=' * 60}")
    print(f"SELF-TEST: {lang}")
    print(f"{'=' * 60}")

    passed = 0
    failed = 0

    def check(name, condition, detail=""):
        nonlocal passed, failed
        if condition:
            passed += 1
            print(f"  PASS: {name}")
        else:
            failed += 1
            msg = f"  FAIL: {name}"
            if detail:
                msg += f" -- {detail}"
            print(msg)

    count = len(meanings)
    check(f"entry count >= 70000", count >= 70000, f"got {count}")
    check(f"entry count <= {EXPECTED_TOTAL_WORDS}", count <= EXPECTED_TOTAL_WORDS, f"got {count}")

    # Al-Fatiha 1:1 word 1 should exist
    key_1_1_1 = "1:1:1"
    check("Al-Fatiha 1:1 word 1 exists", key_1_1_1 in meanings)

    if key_1_1_1 in meanings:
        text = meanings[key_1_1_1]
        check(f"1:1:1 is non-empty", len(text) > 0, f"got '{text}'")
        # For non-Latin-script languages, text should contain non-ASCII characters
        # Indonesian and Turkish use Latin script, so skip this check for them
        if lang not in ("id", "tr"):
            has_non_ascii = any(ord(c) > 127 for c in text)
            check(f"1:1:1 contains non-ASCII ({lang})", has_non_ascii, f"got '{text}'")

    # Last surah should have entries
    nas_keys = [k for k in meanings if k.startswith("114:")]
    check("An-Nas (114) has entries", len(nas_keys) > 0, f"got {len(nas_keys)}")

    print(f"\nResults: {passed} passed, {failed} failed")
    print(f"{'=' * 60}")
    return failed == 0


def main():
    surahs = load_surahs()
    if len(surahs) != 114:
        print(f"ERROR: expected 114 surahs, got {len(surahs)}")
        sys.exit(1)

    all_ok = True
    for lang in LANGUAGES:
        meanings, total = fetch_meanings_for_language(lang, surahs)
        save_meanings(lang, meanings)
        ok = self_test(lang, meanings)
        if not ok:
            all_ok = False

    if not all_ok:
        print("\nSome checks failed. Review warnings above.")
        sys.exit(1)
    else:
        print("\nAll languages fetched and validated successfully.")


if __name__ == "__main__":
    main()
