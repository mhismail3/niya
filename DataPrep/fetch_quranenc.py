#!/usr/bin/env python3
"""Fetch Quran translations from QuranEnc.com per-sura API.

Source: https://quranenc.com/api/v1/translation/sura/<key>/<n>
Output: flat overlay dict keyed by "surah:verse" — same shape as fetch_translations.py.

Per-sura raw JSON is cached under output/quranenc_cache/<key>/sura_<n>.json so
re-runs are offline-fast. To force a re-fetch, delete the cache directory (or
the specific sura file) and re-run.

translations_index.json is NOT written here — fetch_translations.py owns it.
This script only writes output/translations/translation_<output_id>.json,
which fetch_translations.py then picks up via the QURANENC sentinel.
"""
import json
import os
import time
import urllib.error
import urllib.request

EDITIONS = [
    ("pashto_rwwad", "ps_rwwad", "ps", "Pashto", "Rowwad Translation Center", "Rowwad Translation Center / KFGQPC"),
    ("greek_rwwad",  "el_rwwad", "el", "Greek",  "Rowwad Translation Center", "Rowwad Translation Center / KFGQPC"),
]

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output", "translations")
CACHE_ROOT = os.path.join(SCRIPT_DIR, "output", "quranenc_cache")

# Standard verse counts per surah (1-indexed); sums to 6236.
STANDARD_VERSE_COUNTS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99,
    128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35,
    38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11,
    11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40,
    46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8,
    8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
]

EXPECTED_VERSES = sum(STANDARD_VERSE_COUNTS)  # 6236
SURA_URL = "https://quranenc.com/api/v1/translation/sura/{key}/{sura}"

MAX_ATTEMPTS = 3
RETRY_BACKOFF_SECONDS = 1.0
SLEEP_BETWEEN_SURAS = 0.5

# QuranEnc blocks the default urllib User-Agent with 403, so identify as a
# real browser when fetching.
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


def parse_sura_response(data, sura):
    """Flatten a QuranEnc per-sura response into {f"{sura}:{aya}": text}.

    Raises:
        KeyError: if the response shape is wrong (missing `result` or `translation`).
        ValueError: if `result` is empty or any translation is blank.
    """
    if "result" not in data:
        raise KeyError(f"sura {sura}: response missing 'result' key")
    items = data["result"]
    if not items:
        raise ValueError(f"sura {sura}: empty result array")
    overlay = {}
    for item in items:
        aya = item["aya"]  # raises KeyError on bad shape
        text = item["translation"].strip()  # raises KeyError if missing
        if not text:
            raise ValueError(f"sura {sura}: empty translation at aya {aya}")
        overlay[f"{sura}:{aya}"] = text
    return overlay


def _fetch_sura(key, sura, use_cache=True):
    """Fetch and parse a single sura, with optional disk cache and retry."""
    cache_path = os.path.join(CACHE_ROOT, key, f"sura_{sura}.json")
    if use_cache and os.path.exists(cache_path):
        with open(cache_path, "r", encoding="utf-8") as f:
            return json.load(f)

    url = SURA_URL.format(key=key, sura=sura)
    last_err = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read().decode("utf-8")
            data = json.loads(raw)
            if use_cache:
                os.makedirs(os.path.dirname(cache_path), exist_ok=True)
                with open(cache_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False)
            return data
        except urllib.error.HTTPError as e:
            last_err = e
            if 500 <= e.code < 600 and attempt < MAX_ATTEMPTS:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
                continue
            raise
        except urllib.error.URLError as e:
            last_err = e
            if attempt < MAX_ATTEMPTS:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
                continue
            raise
    if last_err:
        raise last_err


def aggregate(key):
    """Fetch all 114 suras for `key` and return the flat overlay dict."""
    overlay = {}
    for sura in range(1, 115):
        data = _fetch_sura(key, sura)
        sura_overlay = parse_sura_response(data, sura)
        expected = STANDARD_VERSE_COUNTS[sura - 1]
        if len(sura_overlay) != expected:
            raise ValueError(
                f"sura {sura}: expected {expected} ayahs, got {len(sura_overlay)}"
            )
        overlay.update(sura_overlay)
        time.sleep(SLEEP_BETWEEN_SURAS)
    if len(overlay) != EXPECTED_VERSES:
        raise ValueError(
            f"aggregate: expected {EXPECTED_VERSES} verses, got {len(overlay)}"
        )
    return overlay


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for key, output_id, _lang, _lang_name, _name, _author in EDITIONS:
        out_path = os.path.join(OUTPUT_DIR, f"translation_{output_id}.json")
        if os.path.exists(out_path):
            print(f"  Skipping {output_id} (already exists)")
            continue
        print(f"Fetching {output_id} from QuranEnc {key}...")
        overlay = aggregate(key)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(overlay, f, ensure_ascii=False)
        size_kb = os.path.getsize(out_path) / 1024
        print(f"  {output_id}: {len(overlay)} verses ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
