#!/usr/bin/env python3
"""
fetch_tafsir_maududi.py — Scrape Tafheem ul Quran (Maududi) from quranx.com.

quranx.com groups verses: e.g. /Tafsir/Maududi/2.1 covers verses 2:1-4.
The page embeds a versesForChapter JS object telling us which verse numbers
have their own page. We first scrape that mapping, then fetch each page.

Content is in <dl class="boxed"> with <dt> (verse reference) and
<dd class="highlightable"> (commentary paragraphs).

Output: Niya/Resources/Data/tafsir_tafheem_ul_quran.json
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from html.parser import HTMLParser

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Niya", "Resources", "Data")
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "tafsir_tafheem_ul_quran.json")
CHECKPOINT_FILE = "/tmp/maududi_checkpoint.json"
BASE_URL = "https://quranx.com/Tafsir/Maududi"
DELAY = 0.4
MAX_RETRIES = 3

SURAH_VERSE_COUNTS = {
    1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75,
    9: 129, 10: 109, 11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128,
    17: 111, 18: 110, 19: 98, 20: 135, 21: 112, 22: 78, 23: 118, 24: 64,
    25: 77, 26: 227, 27: 93, 28: 88, 29: 69, 30: 60, 31: 34, 32: 30,
    33: 73, 34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
    41: 54, 42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29,
    49: 18, 50: 45, 51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96,
    57: 29, 58: 22, 59: 24, 60: 13, 61: 14, 62: 11, 63: 11, 64: 18,
    65: 12, 66: 12, 67: 30, 68: 52, 69: 52, 70: 44, 71: 28, 72: 28,
    73: 20, 74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
    81: 29, 82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26,
    89: 30, 90: 20, 91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19,
    97: 5, 98: 8, 99: 8, 100: 11, 101: 11, 102: 8, 103: 3, 104: 9,
    105: 5, 106: 4, 107: 7, 108: 3, 109: 6, 110: 3, 111: 5, 112: 4,
    113: 5, 114: 6,
}


class TafsirPageParser(HTMLParser):
    """Parse a quranx.com Maududi tafsir page.

    Extracts:
    - verse_range from the <dt> containing <span class="verse__reference">
    - commentary paragraphs from <dd class="highlightable">
    """

    def __init__(self):
        super().__init__()
        self._in_dt = False
        self._in_verse_ref = False
        self._in_dd = False
        self._verse_range = ""
        self._paragraphs: list[str] = []
        self._current = ""

    def handle_starttag(self, tag, attrs):
        cls = dict(attrs).get("class", "")
        if tag == "dt":
            self._in_dt = True
        elif tag == "span" and "verse__reference" in cls:
            self._in_verse_ref = True
        elif tag == "dd" and "highlightable" in cls:
            self._in_dd = True
            self._current = ""

    def handle_endtag(self, tag):
        if tag == "dt":
            self._in_dt = False
        if tag == "span" and self._in_verse_ref:
            self._in_verse_ref = False
        if tag == "dd" and self._in_dd:
            self._in_dd = False
            text = self._current.strip()
            if text:
                self._paragraphs.append(text)

    def handle_data(self, data):
        if self._in_verse_ref:
            self._verse_range = data.strip()
        if self._in_dd:
            self._current += data

    def get_verse_range(self) -> str:
        return self._verse_range

    def get_text(self) -> str:
        parts = []
        for p in self._paragraphs:
            cleaned = " ".join(p.split())
            if cleaned:
                parts.append(cleaned)
        return "\n\n".join(parts)


def parse_verse_range(ref: str, surah: int) -> list[int]:
    """Parse '2.1-4' or '2.1' into list of verse numbers."""
    # Remove surah prefix if present
    ref = ref.strip()
    m = re.match(r'(\d+)\.(\d+)(?:\s*[-–]\s*(\d+))?', ref)
    if not m:
        return []
    start = int(m.group(2))
    end = int(m.group(3)) if m.group(3) else start
    max_verse = SURAH_VERSE_COUNTS.get(surah, 999)
    end = min(end, max_verse)
    return list(range(start, end + 1))


def fetch_page(url: str) -> str | None:
    headers = {
        "User-Agent": "NiyaApp-DataPrep/1.0 (Islamic education app; respectful scraping)",
        "Accept": "text/html",
    }
    req = urllib.request.Request(url, headers=headers)
    for attempt in range(MAX_RETRIES):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if attempt < MAX_RETRIES - 1:
                time.sleep(2 ** (attempt + 1))
            else:
                print(f"    FAILED {url}: HTTP {e.code}")
                return None
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt < MAX_RETRIES - 1:
                time.sleep(2 ** (attempt + 1))
            else:
                print(f"    FAILED {url}: {e}")
                return None
    return None


def extract_verses_for_chapter(html: str) -> dict[int, list[int]]:
    """Extract the versesForChapter JS object from any page."""
    result: dict[int, list[int]] = {}
    pattern = re.compile(r'versesForChapter\[(\d+)\]\s*=\s*\[([^\]]*)\]')
    for m in pattern.finditer(html):
        ch = int(m.group(1))
        verses_str = m.group(2).strip()
        if verses_str:
            verses = [int(v.strip()) for v in verses_str.split(",") if v.strip()]
            result[ch] = verses
    return result


def load_checkpoint() -> dict:
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_checkpoint(data: dict, last_key: str):
    with open(CHECKPOINT_FILE, "w", encoding="utf-8") as f:
        json.dump({"data": data, "last_key": last_key}, f, ensure_ascii=False)


def main():
    print("Fetching Tafheem ul Quran (Maududi) from quranx.com...")

    # Step 1: Get the verse grouping map from any page
    print("  Fetching verse groupings...")
    index_html = fetch_page(f"{BASE_URL}/1.1")
    if not index_html:
        print("ERROR: Could not fetch index page")
        sys.exit(1)

    verses_map = extract_verses_for_chapter(index_html)
    total_pages = sum(len(v) for v in verses_map.values())
    print(f"  Found {len(verses_map)} surahs, {total_pages} pages to fetch")

    # Step 2: Resume support
    checkpoint = load_checkpoint()
    data: dict[str, str] = checkpoint.get("data", {})
    last_key = checkpoint.get("last_key", "")
    skip_until_past = bool(last_key) and last_key in [
        f"{s}.{v}" for s in verses_map for v in verses_map[s]
    ]

    if data:
        print(f"  Resuming after {last_key} ({len(data)} entries cached)")

    fetched_pages = 0
    total_entries = len(data)

    for surah_id in range(1, 115):
        if surah_id not in verses_map:
            continue
        verse_starts = verses_map[surah_id]

        for start_verse in verse_starts:
            page_key = f"{surah_id}.{start_verse}"

            # Skip pages we've already done
            if skip_until_past:
                if page_key == last_key:
                    skip_until_past = False
                continue

            # Check if all verses from this page are already in data
            # (could happen if checkpoint is from a partial run)
            already_done = any(
                f"{surah_id}:{start_verse}" in data
                for _ in [1]
            )
            if already_done:
                continue

            url = f"{BASE_URL}/{page_key}"
            html = fetch_page(url)

            if html:
                parser = TafsirPageParser()
                parser.feed(html)
                text = parser.get_text()
                verse_ref = parser.get_verse_range()

                if text:
                    verses = parse_verse_range(verse_ref, surah_id) if verse_ref else [start_verse]
                    if not verses:
                        verses = [start_verse]
                    for v in verses:
                        data[f"{surah_id}:{v}"] = text
                    total_entries = len(data)

            fetched_pages += 1
            if fetched_pages % 20 == 0:
                print(f"  Progress: {fetched_pages}/{total_pages} pages, "
                      f"{total_entries} verse entries")

            save_checkpoint(data, page_key)
            time.sleep(DELAY)

        print(f"  Surah {surah_id}: {len(verse_starts)} pages fetched")

    # Write output
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

    size_mb = os.path.getsize(OUTPUT_FILE) / (1024 * 1024)
    print(f"\nDone! {total_entries} entries across {fetched_pages} pages")
    print(f"  Written: {OUTPUT_FILE} ({size_mb:.1f} MB)")

    if os.path.exists(CHECKPOINT_FILE):
        os.remove(CHECKPOINT_FILE)


if __name__ == "__main__":
    main()
