#!/usr/bin/env python3
"""
build_noreen_word_data.py — Generate per-word timestamps for Noreen's recitation.

Algorithm:
1. Transcribe each surah with Whisper (word_timestamps=True)
2. Filter non-Arabic noise tokens (hallucinated numbers, etc.)
3. Detect and skip ta'awwudh / bismillah preamble
4. Build per-character timeline from remaining Whisper words
5. Use SequenceMatcher to align known Quranic characters to timeline
6. Extract per-word timestamps from the character alignment

Requirements:
    pip install openai-whisper torch
    brew install ffmpeg

Input:
    DataPrep/noreen_audio/{001-114}.mp3
    Niya/Resources/Data/word_data.json
    Niya/Resources/Data/surahs.json

Output:
    Niya/Resources/Data/noreen_word_data.json
"""

import json
import os
import re
import sys
from difflib import SequenceMatcher

import torch
import whisper
import whisper.timing as _timing

# Monkey-patch: MPS doesn't support float64 in DTW
_original_dtw = _timing.dtw
def _patched_dtw(x):
    return _original_dtw(x.cpu())
_timing.dtw = _patched_dtw

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
AUDIO_DIR = os.path.join(SCRIPT_DIR, "noreen_audio")
WORD_DATA_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "word_data.json")
SURAHS_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "surahs.json")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "noreen_word_data.json")

CDN_BASE = "https://download.quranicaudio.com/quran/noreen_siddiq"


# ---------------------------------------------------------------------------
# Arabic text normalization
# ---------------------------------------------------------------------------

def normalize_arabic(text):
    """Strip diacritics, normalize letter variants for alignment."""
    text = re.sub(r'[\u064B-\u0652\u0670\u06D6-\u06ED\u0610-\u061A]', '', text)
    text = re.sub(r'[\u0622\u0623\u0625\u0671]', '\u0627', text)  # alef variants
    text = text.replace('\u0629', '\u0647')  # teh marbuta → heh
    text = text.replace('\u0640', '')          # tatweel
    return text


def is_arabic_word(text):
    return bool(re.search(r'[\u0600-\u06FF]', text))


# ---------------------------------------------------------------------------
# Whisper output processing
# ---------------------------------------------------------------------------

def extract_whisper_words(result):
    """Extract words with timestamps, filtering non-Arabic noise."""
    words = []
    for seg in result.get('segments', []):
        for w in seg.get('words', []):
            text = w.get('word', '').strip()
            if is_arabic_word(text):
                words.append({
                    'text': text,
                    'norm': normalize_arabic(text).replace(' ', ''),
                    'start': w['start'],
                    'end': w['end'],
                })
    return words


def detect_preamble_end(words, surah_id):
    """Find index of first word that's actual verse text (after ta'awwudh/bismillah).

    Returns the index to start from in the words list.
    """
    if not words:
        return 0

    # --- Detect ta'awwudh: أعوذ بالله من الشيطان الرجيم ---
    ta_end = 0
    for i in range(min(6, len(words))):
        if 'عوذ' in words[i]['norm']:
            # Found ta'awwudh start. Scan forward for its end (الرجيم/الرحيم pattern).
            for j in range(i + 1, min(i + 8, len(words))):
                n = words[j]['norm']
                if 'رحيم' in n or 'رجيم' in n:
                    ta_end = j + 1
                    break
            else:
                ta_end = min(i + 5, len(words))
            break

    # --- Detect bismillah preamble for surahs 2-8, 10-114 ---
    bism_end = ta_end
    if surah_id not in (1, 9):
        for i in range(ta_end, min(ta_end + 5, len(words))):
            if 'بسم' in words[i]['norm']:
                # Bismillah: بسم الله الرحمن الرحيم — scan for الرحيم
                for j in range(i + 1, min(i + 8, len(words))):
                    if 'رحيم' in words[j]['norm']:
                        bism_end = j + 1
                        break
                else:
                    bism_end = min(i + 4, len(words))
                break

    return bism_end


# ---------------------------------------------------------------------------
# Character-level timeline and alignment
# ---------------------------------------------------------------------------

def build_char_timeline(words):
    """Convert Whisper words into per-character (char, start_ms, end_ms) timeline."""
    timeline = []
    for w in words:
        chars = list(w['norm'])
        if not chars:
            continue
        start_ms = int(w['start'] * 1000)
        end_ms = int(w['end'] * 1000)
        dur = max(end_ms - start_ms, 1)
        char_dur = dur / len(chars)
        for i, ch in enumerate(chars):
            cs = start_ms + int(i * char_dur)
            ce = start_ms + int((i + 1) * char_dur)
            timeline.append((ch, cs, ce))
    return timeline


def align_characters(known_words_flat, char_timeline):
    """Align known words to timeline at character level using SequenceMatcher.

    Returns list of (start_ms, end_ms) per known word.
    """
    # Build known character sequence, tracking word boundaries
    known_chars = []
    word_bounds = []  # (char_start_idx, char_end_idx) per word
    for _, _, word in known_words_flat:
        norm = normalize_arabic(word['t']).replace(' ', '')
        start = len(known_chars)
        known_chars.extend(list(norm))
        word_bounds.append((start, len(known_chars)))

    tl_chars = [t[0] for t in char_timeline]

    if not known_chars or not tl_chars:
        return [(0, 0)] * len(known_words_flat)

    # SequenceMatcher finds longest common subsequence blocks
    sm = SequenceMatcher(None, known_chars, tl_chars, autojunk=False)
    blocks = sm.get_matching_blocks()

    # Map: known char index → timeline char index
    k_to_t = {}
    for a, b, size in blocks:
        for i in range(size):
            k_to_t[a + i] = b + i

    # Extract per-word timestamps
    timestamps = []
    for ws, we in word_bounds:
        mapped = [k_to_t[ki] for ki in range(ws, we) if ki in k_to_t]
        if mapped:
            first = min(mapped)
            last = max(mapped)
            timestamps.append((char_timeline[first][1], char_timeline[last][2]))
        else:
            timestamps.append(None)  # will interpolate

    # Interpolate any unmatched words
    for i in range(len(timestamps)):
        if timestamps[i] is not None:
            continue
        prev_end = 0
        for j in range(i - 1, -1, -1):
            if timestamps[j] is not None:
                prev_end = timestamps[j][1]
                break
        next_start = char_timeline[-1][2] if char_timeline else 0
        for j in range(i + 1, len(timestamps)):
            if timestamps[j] is not None:
                next_start = timestamps[j][0]
                break
        mid = (prev_end + next_start) // 2
        timestamps[i] = (mid, mid + 200)

    # Enforce monotonicity
    for i in range(1, len(timestamps)):
        if timestamps[i][0] < timestamps[i - 1][0]:
            timestamps[i] = (timestamps[i - 1][1], max(timestamps[i][1], timestamps[i - 1][1] + 50))

    return timestamps


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_surahs():
    with open(SURAHS_PATH, 'r', encoding='utf-8') as f:
        return {s['id']: s for s in json.load(f)}


def load_word_data():
    with open(WORD_DATA_PATH, 'r', encoding='utf-8') as f:
        return json.load(f)


def get_known_words_flat(word_data, surah_id):
    """Flat list of (verse_id, word_index, word_dict) for a surah, in order."""
    surah_key = str(surah_id)
    if surah_key not in word_data:
        return []
    verses = word_data[surah_key]
    result = []
    for vk in sorted(verses.keys(), key=int):
        for i, w in enumerate(verses[vk]['w']):
            result.append((int(vk), i, w))
    return result


# ---------------------------------------------------------------------------
# Per-surah processing
# ---------------------------------------------------------------------------

def process_surah(model, surah_id, word_data, surahs):
    audio_path = os.path.join(AUDIO_DIR, f"{surah_id:03d}.mp3")
    if not os.path.exists(audio_path):
        print(f"  [SKIP] Audio not found: {audio_path}")
        return None

    surah_info = surahs.get(surah_id)
    expected_verses = surah_info['totalVerses'] if surah_info else 0

    # 1. Transcribe
    result = model.transcribe(
        audio_path,
        language="ar",
        word_timestamps=True,
        condition_on_previous_text=True,
    )

    # 2. Extract and filter whisper words
    whisper_words = extract_whisper_words(result)
    if not whisper_words:
        print(f"  [FAIL] No Arabic words detected")
        return None

    # 3. Skip preamble
    preamble_end = detect_preamble_end(whisper_words, surah_id)
    verse_words = whisper_words[preamble_end:]

    if not verse_words:
        print(f"  [FAIL] No words after preamble")
        return None

    # 4. Build character timeline
    char_timeline = build_char_timeline(verse_words)

    # 5. Get known words
    known_flat = get_known_words_flat(word_data, surah_id)
    if not known_flat:
        print(f"  [SKIP] No known words")
        return None

    # 6. Align
    timestamps = align_characters(known_flat, char_timeline)

    if len(timestamps) != len(known_flat):
        print(f"  [FAIL] Timestamp count {len(timestamps)} != word count {len(known_flat)}")
        return None

    # 7. Build output structure
    surah_key = str(surah_id)
    audio_url = f"{CDN_BASE}/{surah_id:03d}.mp3"
    verses = word_data[surah_key]
    output_verses = {}

    word_idx = 0
    for vk in sorted(verses.keys(), key=int):
        verse = verses[vk]
        words_out = []
        for w in verse['w']:
            s_ms, e_ms = timestamps[word_idx]
            words_out.append({
                'p': w['p'],
                't': w['t'],
                'tr': w['tr'],
                'en': w['en'],
                'a': w['a'],
                's': s_ms,
                'e': e_ms,
            })
            word_idx += 1

        vs = words_out[0]['s'] if words_out else 0
        ve = words_out[-1]['e'] if words_out else 0

        # Bismillah handling: surahs 2-8, 10-114 — set vs=0 so bismillah plays as intro
        if int(vk) == 1 and surah_id not in (1, 9):
            vs = 0

        output_verses[vk] = {
            'au': audio_url,
            'vs': vs,
            've': ve,
            'w': words_out,
        }

    # 8. Validate
    actual_verses = len(output_verses)
    actual_words = sum(len(v['w']) for v in output_verses.values())
    expected_words = len(known_flat)

    warnings = []
    if actual_verses != expected_verses:
        warnings.append(f"verses {actual_verses} != {expected_verses}")
    if actual_words != expected_words:
        warnings.append(f"words {actual_words} != {expected_words}")

    # Check monotonicity
    all_starts = [w['s'] for vk in sorted(output_verses.keys(), key=int) for w in output_verses[vk]['w']]
    non_mono = sum(1 for i in range(1, len(all_starts)) if all_starts[i] < all_starts[i - 1])
    if non_mono:
        warnings.append(f"{non_mono} non-monotonic")

    # Check large gaps
    gaps = sum(1 for i in range(1, len(all_starts)) if all_starts[i] - all_starts[i - 1] > 5000)
    if gaps:
        warnings.append(f"{gaps} gaps > 5s")

    # Character match rate
    known_chars = ''.join(normalize_arabic(w[2]['t']).replace(' ', '') for w in known_flat)
    tl_chars = ''.join(t[0] for t in char_timeline)
    sm = SequenceMatcher(None, known_chars, tl_chars, autojunk=False)
    ratio = sm.ratio()

    status = "OK" if not warnings else f"WARN: {'; '.join(warnings)}"
    print(f"  Surah {surah_id:3d}: {actual_verses}v, {actual_words}w, "
          f"char match {ratio:.1%} — {status}")

    return output_verses


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if not os.path.isdir(AUDIO_DIR):
        print(f"Audio directory not found: {AUDIO_DIR}")
        print("Run fetch_noreen_audio.py first.")
        sys.exit(1)

    missing = [i for i in range(1, 115)
               if not os.path.exists(os.path.join(AUDIO_DIR, f"{i:03d}.mp3"))]
    if missing:
        print(f"Missing audio: surahs {missing}")
        sys.exit(1)

    print("Loading Whisper model (base, CPU)...")
    model = whisper.load_model("base", device="cpu")

    print("Loading word data and surahs...")
    word_data = load_word_data()
    surahs = load_surahs()

    output = {}
    failed = []

    for surah_id in range(1, 115):
        print(f"\nProcessing surah {surah_id}/114...")
        result = process_surah(model, surah_id, word_data, surahs)
        if result is not None:
            output[str(surah_id)] = result
        else:
            failed.append(surah_id)

    print(f"\nWriting {OUTPUT_PATH}...")
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, separators=(',', ':'))

    total_words = sum(len(v['w']) for s in output.values() for v in s.values())
    total_verses = sum(len(s) for s in output.values())
    size_mb = os.path.getsize(OUTPUT_PATH) / (1024 * 1024)

    print(f"\nDone! {len(output)} surahs, {total_verses} verses, {total_words} words")
    print(f"Output: {size_mb:.1f} MB")
    if failed:
        print(f"Failed: {failed}")


if __name__ == "__main__":
    main()
