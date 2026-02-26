#!/usr/bin/env python3
"""
Fetch word-by-word data and audio timing from Quran.com API v4.

Produces Niya/Resources/Data/word_data.json with per-word Arabic text,
transliteration, English translation, and millisecond-accurate audio timing
synced to Mishari al-Afasy's recitation.

Usage:
    python3 DataPrep/fetch_word_data.py
"""
import json
import math
import os
import sys
import time
import urllib.request
import urllib.error

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SURAHS_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "surahs.json")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "word_data.json")

WORDS_API = "https://api.quran.com/api/v4/verses/by_chapter/{ch}?language=en&words=true&word_fields=text_uthmani&per_page=300&page={page}"
TIMING_API = "https://api.quran.com/api/v4/chapter_recitations/7/{ch}?segments=true"

RATE_LIMIT = 0.5
MAX_RETRIES = 3
RETRY_BACKOFF = 2.0
REQUEST_TIMEOUT = 30

EXPECTED_TOTAL_VERSES = 6236


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
            print(f"    retry {attempt}/{MAX_RETRIES} after {wait}s — {e}")
            time.sleep(wait)
            return api_get(url, attempt + 1)
        raise


def fetch_words_for_surah(ch):
    """Fetch all word-by-word data for a surah, handling pagination."""
    all_verses = []
    page = 1
    while True:
        url = WORDS_API.format(ch=ch, page=page)
        data = api_get(url)
        verses = data.get("verses", [])
        all_verses.extend(verses)
        next_page = data.get("pagination", {}).get("next_page")
        if next_page is None:
            break
        page = next_page
        time.sleep(RATE_LIMIT)
    return all_verses


def fetch_timing_for_surah(ch):
    """Fetch audio timing with segments for a surah."""
    url = TIMING_API.format(ch=ch)
    data = api_get(url)
    af = data.get("audio_file")
    if not af:
        return None
    return af


def extract_words(verse_data):
    """Extract word-only entries (skip verse-end markers) from API response."""
    words = []
    for w in verse_data.get("words", []):
        if w.get("char_type_name") != "word":
            continue
        transliteration = w.get("transliteration") or {}
        translation = w.get("translation") or {}
        audio_url = w.get("audio_url") or ""
        # Normalize audio_url to relative path (strip CDN prefix)
        if audio_url.startswith("https://"):
            # Keep just the path portion after the domain
            parts = audio_url.split("/")
            # Find "wbw" segment and keep from there
            for i, part in enumerate(parts):
                if part == "wbw":
                    audio_url = "/".join(parts[i:])
                    break
        words.append({
            "p": w.get("position", 0),
            "t": w.get("text_uthmani", ""),
            "tr": transliteration.get("text", ""),
            "en": translation.get("text", ""),
            "a": audio_url,
        })
    return words


def interpolate_timing(word_count, verse_start_ms, verse_end_ms):
    """Generate evenly-spaced timing for words when segments are unavailable."""
    if word_count == 0:
        return []
    duration = verse_end_ms - verse_start_ms
    per_word = duration / word_count
    timings = []
    for i in range(word_count):
        s = verse_start_ms + round(per_word * i)
        e = verse_start_ms + round(per_word * (i + 1))
        timings.append((i + 1, s, e))
    return timings


def clean_segments(raw_segments, word_count, verse_start_ms, verse_end_ms):
    """
    Validate and repair segment timing data.

    Handles: malformed entries, missing segments, out-of-order positions,
    overlapping times, and gaps between consecutive words.
    """
    if not raw_segments:
        return interpolate_timing(word_count, verse_start_ms, verse_end_ms)

    # Parse segments — each is [position, start_ms, end_ms, ...]
    parsed = []
    for seg in raw_segments:
        if not isinstance(seg, (list, tuple)) or len(seg) < 3:
            continue
        pos, s, e = seg[0], seg[1], seg[2]
        if not all(isinstance(v, (int, float)) for v in (pos, s, e)):
            continue
        pos, s, e = int(pos), int(s), int(e)
        if s < 0 or e < 0:
            continue
        # Malformed: no duration
        if e <= s:
            continue
        parsed.append((pos, s, e))

    if not parsed:
        return interpolate_timing(word_count, verse_start_ms, verse_end_ms)

    # Sort by position
    parsed.sort(key=lambda x: x[0])

    # Deduplicate positions — keep first occurrence
    seen = set()
    deduped = []
    for pos, s, e in parsed:
        if pos not in seen:
            seen.add(pos)
            deduped.append((pos, s, e))
    parsed = deduped

    # If segment count doesn't match word count, interpolate
    if len(parsed) != word_count:
        return interpolate_timing(word_count, verse_start_ms, verse_end_ms)

    # Fix overlaps: clamp each segment's start to previous segment's end
    for i in range(1, len(parsed)):
        prev_pos, prev_s, prev_e = parsed[i - 1]
        cur_pos, cur_s, cur_e = parsed[i]
        if cur_s < prev_e:
            cur_s = prev_e
            if cur_e <= cur_s:
                cur_e = cur_s + 1
            parsed[i] = (cur_pos, cur_s, cur_e)

    # Close gaps > 1ms between consecutive segments
    for i in range(1, len(parsed)):
        prev_pos, prev_s, prev_e = parsed[i - 1]
        cur_pos, cur_s, cur_e = parsed[i]
        if cur_s > prev_e + 1:
            cur_s = prev_e
            parsed[i] = (cur_pos, cur_s, cur_e)

    return parsed


def build_surah_data(ch, surah_info):
    """Build complete word-by-word data for one surah."""
    print(f"  [{ch:>3}/114] {surah_info['transliteration']} ({surah_info['totalVerses']} verses)")

    # Fetch words
    verses_raw = fetch_words_for_surah(ch)
    time.sleep(RATE_LIMIT)

    # Fetch timing
    timing_raw = fetch_timing_for_surah(ch)
    time.sleep(RATE_LIMIT)

    if timing_raw is None:
        print(f"    WARNING: no timing data for surah {ch}")

    audio_url = ""
    verse_timings = {}

    if timing_raw:
        audio_url = timing_raw.get("audio_url", "")
        for vt in timing_raw.get("timestamps", []):
            vk = vt.get("verse_key", "")
            if ":" not in vk:
                continue
            verse_num = int(vk.split(":")[1])
            verse_timings[verse_num] = vt

    surah_out = {}
    expected_count = surah_info["totalVerses"]

    if len(verses_raw) != expected_count:
        print(f"    WARNING: expected {expected_count} verses, got {len(verses_raw)}")

    for verse_data in verses_raw:
        verse_key = verse_data.get("verse_key", "")
        if ":" not in verse_key:
            continue
        verse_num = int(verse_key.split(":")[1])
        words = extract_words(verse_data)

        # Get timing
        vt = verse_timings.get(verse_num, {})
        vs = int(vt.get("timestamp_from", 0))
        ve = int(vt.get("timestamp_to", 0))
        raw_segs = vt.get("segments", [])

        segments = clean_segments(raw_segs, len(words), vs, ve)

        # Apply timing to words
        for word, seg in zip(words, segments):
            word["s"] = seg[1]
            word["e"] = seg[2]

        # If we have fewer segments than words (shouldn't happen after clean),
        # fill remaining with interpolated timing
        if len(segments) < len(words):
            last_e = segments[-1][2] if segments else vs
            remaining = len(words) - len(segments)
            per_word = (ve - last_e) / remaining if remaining > 0 else 0
            for i in range(len(segments), len(words)):
                words[i]["s"] = last_e + round(per_word * (i - len(segments)))
                words[i]["e"] = last_e + round(per_word * (i - len(segments) + 1))

        surah_out[str(verse_num)] = {
            "au": audio_url,
            "vs": vs,
            "ve": ve,
            "w": words,
        }

    return surah_out


def build_all():
    """Fetch and assemble word data for the entire Quran."""
    surahs = load_surahs()
    if len(surahs) != 114:
        print(f"ERROR: expected 114 surahs in surahs.json, got {len(surahs)}")
        sys.exit(1)

    result = {}
    total_verses = 0
    total_words = 0

    print("Fetching word-by-word data for all 114 surahs...")
    print()

    for ch in range(1, 115):
        surah_info = surahs[ch]
        surah_data = build_surah_data(ch, surah_info)
        result[str(ch)] = surah_data
        v_count = len(surah_data)
        w_count = sum(len(v["w"]) for v in surah_data.values())
        total_verses += v_count
        total_words += w_count
        print(f"    {v_count} verses, {w_count} words")

    print()
    print(f"Total: {total_verses} verses, {total_words} words")

    if total_verses != EXPECTED_TOTAL_VERSES:
        print(f"WARNING: expected {EXPECTED_TOTAL_VERSES} verses, got {total_verses}")

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))

    size_mb = os.path.getsize(OUTPUT_PATH) / (1024 * 1024)
    print(f"Saved: {OUTPUT_PATH} ({size_mb:.1f} MB)")

    return result


def self_test():
    """Validate the generated output file."""
    print()
    print("=" * 60)
    print("SELF-TEST")
    print("=" * 60)

    if not os.path.exists(OUTPUT_PATH):
        print("FAIL: output file not found")
        return False

    with open(OUTPUT_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    surahs = load_surahs()
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
                msg += f" — {detail}"
            print(msg)

    # 1. Surah count
    check("surah count == 114", len(data) == 114, f"got {len(data)}")

    # 2. All surahs present
    all_present = all(str(ch) in data for ch in range(1, 115))
    check("all 114 surahs present", all_present)

    # 3. Total verse count
    total_verses = sum(len(data[str(ch)]) for ch in range(1, 115) if str(ch) in data)
    check(
        f"total verse count == {EXPECTED_TOTAL_VERSES}",
        total_verses == EXPECTED_TOTAL_VERSES,
        f"got {total_verses}",
    )

    # 4. Per-surah verse counts match surahs.json
    mismatched_surahs = []
    for ch in range(1, 115):
        expected = surahs[ch]["totalVerses"]
        actual = len(data.get(str(ch), {}))
        if actual != expected:
            mismatched_surahs.append(f"{ch}(exp={expected},got={actual})")
    check(
        "per-surah verse counts match surahs.json",
        len(mismatched_surahs) == 0,
        ", ".join(mismatched_surahs[:5]),
    )

    # 5. Every verse has >= 1 word
    empty_verses = []
    for ch in range(1, 115):
        for vk, vd in data.get(str(ch), {}).items():
            if len(vd.get("w", [])) == 0:
                empty_verses.append(f"{ch}:{vk}")
    check(
        "every verse has >= 1 word",
        len(empty_verses) == 0,
        f"{len(empty_verses)} empty: {', '.join(empty_verses[:5])}",
    )

    # 6. Every verse has timing data
    no_timing = []
    for ch in range(1, 115):
        for vk, vd in data.get(str(ch), {}).items():
            if not vd.get("au"):
                no_timing.append(f"{ch}:{vk}")
    check(
        "every verse has audio URL",
        len(no_timing) == 0,
        f"{len(no_timing)} missing: {', '.join(no_timing[:5])}",
    )

    # 7. Valid word timing (s < e, no negatives)
    bad_timing = []
    for ch in range(1, 115):
        for vk, vd in data.get(str(ch), {}).items():
            for w in vd.get("w", []):
                s, e = w.get("s", -1), w.get("e", -1)
                if s < 0 or e < 0 or s >= e:
                    bad_timing.append(f"{ch}:{vk} p={w.get('p')}")
    check(
        "all word timings valid (s >= 0, e > s)",
        len(bad_timing) == 0,
        f"{len(bad_timing)} invalid: {', '.join(bad_timing[:5])}",
    )

    # 8. No gaps > 100ms between consecutive words
    large_gaps = []
    for ch in range(1, 115):
        for vk, vd in data.get(str(ch), {}).items():
            words = vd.get("w", [])
            for i in range(1, len(words)):
                prev_e = words[i - 1].get("e", 0)
                cur_s = words[i].get("s", 0)
                gap = cur_s - prev_e
                if gap > 100:
                    large_gaps.append(f"{ch}:{vk} w{i}-{i+1} gap={gap}ms")
    check(
        "no gaps > 100ms between consecutive words",
        len(large_gaps) == 0,
        f"{len(large_gaps)} gaps: {', '.join(large_gaps[:5])}",
    )

    # 9. Al-Fatiha 1:1 has 4 words (Bismillah ir-Rahman ir-Raheem = 4 words)
    fatiha_1_words = len(data.get("1", {}).get("1", {}).get("w", []))
    check("Al-Fatiha 1:1 word count == 4", fatiha_1_words == 4, f"got {fatiha_1_words}")

    # 10. Al-Baqarah 2:282 (longest verse, ~50 words) stress test
    baqarah_282 = data.get("2", {}).get("282", {})
    b282_words = len(baqarah_282.get("w", []))
    check(
        "Al-Baqarah 2:282 has >= 40 words (longest verse)",
        b282_words >= 40,
        f"got {b282_words}",
    )
    # Verify timing continuity for the longest verse
    if b282_words > 0:
        w282 = baqarah_282["w"]
        timing_ok = all(w282[i]["e"] <= w282[i + 1]["s"] + 1 for i in range(len(w282) - 1))
        check("2:282 timing continuity (no major overlaps)", timing_ok)

    # 11. An-Nas 114:1 word count
    nas_1_words = len(data.get("114", {}).get("1", {}).get("w", []))
    check("An-Nas 114:1 has >= 2 words", nas_1_words >= 2, f"got {nas_1_words}")

    print()
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 60)

    return failed == 0


def main():
    build_all()
    ok = self_test()
    if not ok:
        print()
        print("Some checks failed. Review warnings above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
