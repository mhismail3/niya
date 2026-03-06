#!/usr/bin/env python3
"""Download and convert Dr. Mustafa Khattab's 'The Clear Quran' translation.

Source: faisalill/quran_db on GitHub (mustafakhattab2018.json).
Output: flat overlay dict keyed by "surah:verse" for the app's translation system.
"""
import html
import json
import os
import re
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output", "translations")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "translation_en_clearquran.json")
SOURCE_URL = "https://raw.githubusercontent.com/faisalill/quran_db/main/mustafakhattab2018.json"
SOURCE_CACHE = os.path.join(SCRIPT_DIR, "output", "mustafakhattab2018.json")

TRANSLATION_KEY = "Mustafa Khattab 2018"

# Standard verse counts per surah (1-indexed)
STANDARD_VERSE_COUNTS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99,
    128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35,
    38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11,
    11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40,
    46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8,
    8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
]


def normalize_text(text, surah, verse):
    """Clean raw Khattab text for app consumption."""
    text = html.unescape(text)
    text = re.sub(r'<[^>]+>', '', text)
    text = text.strip()
    if surah == 77 and verse == 48:
        if '˹before Allah,' in text and '˹before Allah˺,' not in text:
            text = text.replace('˹before Allah,', '˹before Allah˺,')
    return text


def download_source():
    """Download source JSON, caching locally."""
    os.makedirs(os.path.dirname(SOURCE_CACHE), exist_ok=True)
    if os.path.exists(SOURCE_CACHE):
        print(f"Using cached source: {SOURCE_CACHE}")
    else:
        print(f"Downloading from {SOURCE_URL}...")
        urllib.request.urlretrieve(SOURCE_URL, SOURCE_CACHE)
        print(f"Saved to {SOURCE_CACHE}")
    with open(SOURCE_CACHE, "r", encoding="utf-8") as f:
        return json.load(f)


def convert(source_data):
    """Convert nested source format to flat overlay dict."""
    overlay = {}
    for surah_key, surah_data in source_data.items():
        surah_num = int(surah_key)
        ayahs = surah_data.get("Ayahs", {})
        for verse_key, verse_data in ayahs.items():
            verse_num = int(verse_key)
            raw_text = verse_data.get(TRANSLATION_KEY, "")
            text = normalize_text(raw_text, surah_num, verse_num)
            overlay[f"{surah_num}:{verse_num}"] = text
    return overlay


def self_test(overlay):
    """Run basic sanity checks before writing output."""
    errors = []

    if len(overlay) != 6236:
        errors.append(f"Expected 6236 verses, got {len(overlay)}")

    empty = [k for k, v in overlay.items() if not v.strip()]
    if empty:
        errors.append(f"{len(empty)} empty translations: {empty[:5]}")

    html_tags = [k for k, v in overlay.items() if '<' in v and '>' in v]
    if html_tags:
        errors.append(f"{len(html_tags)} verses still have HTML tags: {html_tags[:5]}")

    html_entities = [k for k, v in overlay.items() if '&#' in v]
    if html_entities:
        errors.append(f"{len(html_entities)} verses still have HTML entities: {html_entities[:5]}")

    v1_1 = overlay.get("1:1", "")
    if "Allah" not in v1_1:
        errors.append(f"1:1 doesn't contain 'Allah': {v1_1[:80]}")

    v2_1 = overlay.get("2:1", "")
    if "<i>" in v2_1:
        errors.append(f"2:1 still has <i> tags: {v2_1[:80]}")

    for key, text in overlay.items():
        open_count = text.count('\u02f9')  # ˹
        close_count = text.count('\u02fa')  # ˺
        if open_count != close_count:
            errors.append(f"{key}: mismatched brackets ({open_count} open, {close_count} close)")

    if errors:
        print("SELF-TEST FAILED:")
        for e in errors:
            print(f"  - {e}")
        raise SystemExit(1)
    print("Self-test passed.")


def main():
    source_data = download_source()
    overlay = convert(source_data)
    self_test(overlay)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(overlay, f, ensure_ascii=False)

    size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    print(f"Wrote {len(overlay)} verses to {OUTPUT_PATH} ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
