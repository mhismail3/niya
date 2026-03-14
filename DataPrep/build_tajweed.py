#!/usr/bin/env python3
"""Build tajweed_hafs.json from Tanzil Uthmanic text + cpfair/quran-tajweed annotations.

Reads:
  - source/tajweed/tanzil_uthmani.txt          (Tanzil Uthmanic Hafs text, pipe-delimited)
  - source/tajweed/tajweed.hafs.uthmani-pause-sajdah.json  (character-level annotations)

Writes:
  - ../Niya/Resources/Data/tajweed_hafs.json

The output is keyed by surah ID (string), matching verses_hafs.json structure.
Each entry contains the Tanzil Arabic text + tajweed annotation ranges.

IMPORTANT: The app displays basmala as a separate header and does NOT include it
in verse text. Tanzil text includes basmala in ayah 1 of surahs 2-114 (except 9).
This script strips the basmala prefix and adjusts annotation indices accordingly.
"""

import json
import os
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
SOURCE_DIR = SCRIPT_DIR / "source" / "tajweed"
OUTPUT_PATH = SCRIPT_DIR.parent / "Niya" / "Resources" / "Data" / "tajweed_hafs.json"

TANZIL_PATH = SOURCE_DIR / "tanzil_uthmani.txt"
TAJWEED_PATH = SOURCE_DIR / "tajweed.hafs.uthmani-pause-sajdah.json"

# cpfair source names → TajweedRule rawValues (single-letter tags)
RULE_MAP = {
    "hamzat_wasl": "h",
    "lam_shamsiyyah": "l",
    "madd_2": "n",
    "madd_munfasil": "p",
    "madd_246": "p",
    "madd_muttasil": "o",
    "madd_6": "m",
    "ghunnah": "g",
    "qalqalah": "q",
    "silent": "s",
    "ikhfa": "f",
    "idghaam_ghunnah": "a",
    "idghaam_no_ghunnah": "u",
    "iqlab": "i",
    "ikhfa_shafawi": "c",
    "idghaam_mutajanisayn": "d",
    "idghaam_shafawi": "w",
    "idghaam_mutaqaribayn": "b",
    "lam_jalalah": "j",
    "ra_tafkheem": "r",
    "ra_tarqeeq": "e",
    "idhaar": "z",
}


def load_tanzil_text():
    """Parse tanzil_uthmani.txt into {(surah, ayah): text} dict."""
    verses = {}
    with open(TANZIL_PATH, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|", 2)
            if len(parts) != 3:
                continue
            surah, ayah, text = int(parts[0]), int(parts[1]), parts[2]
            verses[(surah, ayah)] = text
    return verses


def load_tajweed_annotations():
    """Parse cpfair tajweed JSON into {(surah, ayah): [annotations]} dict."""
    with open(TAJWEED_PATH, encoding="utf-8") as f:
        data = json.load(f)

    annotations = {}
    for entry in data:
        key = (entry["surah"], entry["ayah"])
        annotations[key] = entry["annotations"]
    return annotations


def detect_basmala(tanzil_verses):
    """Get the basmala text from surah 1, ayah 1."""
    basmala = tanzil_verses.get((1, 1), "")
    if not basmala:
        print("ERROR: Cannot find surah 1 ayah 1 for basmala detection", file=sys.stderr)
        sys.exit(1)
    return basmala


# The ending of every basmala: ٱلرَّحِيمِ
BASMALA_ENDING = "\u0671\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650"


def strip_basmala(text, basmala):
    """Strip basmala prefix + trailing space from text. Returns (stripped_text, chars_removed).

    Some surahs have tajweed-modified basmalas (e.g. extra shadda on ba).
    We handle this by also searching for the basmala ending pattern.
    """
    # Try exact basmala + space
    prefix = basmala + " "
    if text.startswith(prefix):
        return text[len(prefix):], len(prefix)

    # Try basmala + thin space (U+2009)
    prefix_thin = basmala + "\u2009"
    if text.startswith(prefix_thin):
        return text[len(prefix_thin):], len(prefix_thin)

    # Try just basmala (no trailing space — edge case)
    if text.startswith(basmala) and len(text) > len(basmala):
        next_char = text[len(basmala)]
        if next_char in (" ", "\u2009", "\u200b", "\u00a0"):
            offset = len(basmala) + 1
            return text[offset:], offset

    # Fallback: find the basmala ending pattern and strip up to it + separator
    idx = text.find(BASMALA_ENDING)
    if idx != -1 and idx < 60:
        end = idx + len(BASMALA_ENDING)
        if end < len(text) and text[end] in (" ", "\u2009", "\u200b", "\u00a0"):
            end += 1
        return text[end:], end

    if text.startswith(basmala):
        return text[len(basmala):], len(basmala)

    print(f"WARNING: Could not strip basmala from text starting with: {text[:50]!r}")
    return text, 0


def adjust_annotations(annotations, chars_removed):
    """Adjust annotation indices after stripping a prefix.

    - Annotations fully within the stripped prefix are dropped.
    - Annotations spanning the boundary are clipped (start set to 0).
    - All remaining annotations have start/end reduced by chars_removed.
    """
    if chars_removed == 0:
        return annotations

    adjusted = []
    for ann in annotations:
        start = ann["start"]
        end = ann["end"]

        # Fully within stripped prefix — drop
        if end <= chars_removed:
            continue

        # Clip start if it falls within the prefix
        if start < chars_removed:
            start = chars_removed

        adjusted.append({
            "rule": ann["rule"],
            "start": start - chars_removed,
            "end": end - chars_removed,
        })

    return adjusted


def grapheme_len(text):
    """Count grapheme clusters (matching Swift String.count)."""
    count = 0
    for ch in text:
        if not unicodedata.category(ch).startswith("M"):
            count += 1
    return count


def to_grapheme_indices(text, annotations):
    """Convert codepoint-based indices to grapheme cluster indices.

    Swift String.count uses Extended Grapheme Clusters. Arabic combining
    diacritics (Unicode category M) merge with the preceding base character.
    """
    # Build codepoint index → grapheme cluster index mapping
    cp_to_gc = []
    gc_idx = -1
    for ch in text:
        if not unicodedata.category(ch).startswith("M"):
            gc_idx += 1
        cp_to_gc.append(gc_idx)
    total_gc = gc_idx + 1

    result = []
    for ann in annotations:
        start_cp = ann["start"]
        end_cp = ann["end"]

        gc_start = cp_to_gc[start_cp] if start_cp < len(cp_to_gc) else total_gc
        # end is exclusive: map the last included codepoint, then +1
        if end_cp > 0 and end_cp <= len(cp_to_gc):
            gc_end = cp_to_gc[end_cp - 1] + 1
        else:
            gc_end = total_gc

        result.append({
            "rule": ann["rule"],
            "start": gc_start,
            "end": gc_end,
        })
    return result


# Pattern: lam + lam + shadda + fatha + ha (the word Allah in Uthmanic script)
ALLAH_PATTERN = re.compile("\u0644\u0644\u0651\u064e\u0647")


def detect_lam_jalalah(text):
    """Detect Lam al-Jalalah in the word Allah and return annotations.

    Covers the second lam (mushaddad) through the ha — in the Uthmanic hafs
    font the ha renders elevated above the lam as part of the Allah ligature,
    so both need coloring and the wider range provides a reliable tap target.
    Returns a list of annotation dicts with codepoint-based indices.
    """
    annotations = []
    for m in ALLAH_PATTERN.finditer(text):
        # Cover both lams + shadda + fatha: the two lams form a ligature
        # in the Uthmanic font, so both must share the color attribute for
        # CoreText to color the entire glyph.
        first_lam_cp = m.start()
        fatha_cp = m.start() + 3  # last combining mark before the ha
        annotations.append({
            "rule": "j",
            "start": first_lam_cp,
            "end": fatha_cp + 1,
        })
    return annotations


def get_marks(chars, i):
    """Collect combining marks after base char at codepoint index i."""
    marks = []
    j = i + 1
    while j < len(chars) and unicodedata.category(chars[j]).startswith("M"):
        marks.append(chars[j])
        j += 1
    return marks


def get_preceding_vowel(chars, i):
    """Walk backward from index i to find the preceding base letter's vowel marks.

    Returns (marks_list, base_char) where marks_list are the combining marks
    on the preceding base letter, and base_char is the base letter itself.
    """
    j = i - 1
    # Skip any combining marks that belong to the Ra itself (shouldn't happen but safe)
    while j >= 0 and unicodedata.category(chars[j]).startswith("M"):
        j -= 1
    # j is now at some non-mark char (space, base letter, etc.)
    # Skip spaces/non-letters to find the actual preceding base letter
    while j >= 0 and not unicodedata.category(chars[j]).startswith("L"):
        j -= 1
    if j < 0:
        return [], None
    base_char = chars[j]
    return get_marks(chars, j), base_char


def get_next_base(chars, start):
    """Find the next base letter after index start (skipping combining marks and spaces)."""
    j = start
    while j < len(chars):
        cat = unicodedata.category(chars[j])
        if cat.startswith("L"):
            return chars[j]
        j += 1
    return None


# Arabic diacritics
_FATHA = "\u064E"
_FATHATAN = "\u064B"
_DAMMA = "\u064F"
_DAMMATAN = "\u064C"
_KASRA = "\u0650"
_KASRATAN = "\u064D"
_SHADDA = "\u0651"
_SUKUN = "\u0652"
_SUPERSCRIPT_ALEF = "\u0670"

_HEAVY_VOWELS = {_FATHA, _FATHATAN, _DAMMA, _DAMMATAN}
_LIGHT_VOWELS = {_KASRA, _KASRATAN}

# 7 isti'la (heavy) letters
_ISTILA_LETTERS = {
    "\u062E",  # خ Kha
    "\u0635",  # ص Sad
    "\u0636",  # ض Dad
    "\u0637",  # ط Ta
    "\u0638",  # ظ Zha
    "\u063A",  # غ Ghayn
    "\u0642",  # ق Qaf
}

# Long vowel letters for the "no preceding marks" fallback
_ALEF = "\u0627"
_ALEF_WASLA = "\u0671"
_WAW = "\u0648"
_YA = "\u064A"


def classify_ra(chars, i):
    """Classify Ra at codepoint index i. Returns 'r' (tafkheem), 'e' (tarqeeq), or None."""
    marks = get_marks(chars, i)
    mark_set = set(marks)

    has_shadda = _SHADDA in mark_set
    has_sukun = _SUKUN in mark_set

    # Step 1: Ra with vowel directly on it
    if not has_sukun:
        if mark_set & _HEAVY_VOWELS:
            return "r"
        if mark_set & _LIGHT_VOWELS:
            return "e"
        if _SUPERSCRIPT_ALEF in mark_set:
            return "r"
        if has_shadda:
            # Shadda but no vowel mark — shouldn't happen but default tafkheem
            return "r"
        # No marks at all (9 cases) — skip
        if not marks:
            return None
        # Has some marks but none we recognize as vowels — skip
        return None

    # Step 2: Ra Sakin (has sukun)
    prev_marks, prev_base = get_preceding_vowel(chars, i)
    prev_mark_set = set(prev_marks)

    if prev_mark_set & {_FATHA, _FATHATAN}:
        return "r"
    if prev_mark_set & {_DAMMA, _DAMMATAN}:
        return "r"
    if _SHADDA in prev_mark_set and prev_mark_set & {_FATHA, _FATHATAN, _DAMMA, _DAMMATAN}:
        return "r"

    if prev_mark_set & _LIGHT_VOWELS or (_SHADDA in prev_mark_set and prev_mark_set & _LIGHT_VOWELS):
        # Step 3: Ra Sakin after Kasra — check next letter for isti'la
        # Skip past Ra's own marks to find next base letter
        j = i + 1 + len(marks)
        next_base = get_next_base(chars, j)
        if next_base in _ISTILA_LETTERS:
            return "r"
        return "e"

    # No preceding vowel marks — check if preceded by a long vowel letter
    if prev_base in (_ALEF, _ALEF_WASLA):
        return "r"
    if prev_base == _YA:
        return "e"
    if prev_base == _WAW:
        return "r"

    # Default: tafkheem
    return "r"


def detect_ra_rules(text):
    """Detect Ra Tafkheem/Tarqeeq rules and return annotations with codepoint indices."""
    chars = list(text)
    annotations = []
    RA = "\u0631"

    for i, ch in enumerate(chars):
        if ch != RA:
            continue

        rule = classify_ra(chars, i)
        if rule is None:
            continue

        # Annotation covers Ra + all its combining marks
        end = i + 1
        while end < len(chars) and unicodedata.category(chars[end]).startswith("M"):
            end += 1

        annotations.append({
            "rule": rule,
            "start": i,
            "end": end,
        })

    return annotations


# Noon (U+0646)
_NOON = "\u0646"

# Tanween marks
_TANWEEN = {_FATHATAN, _KASRATAN, _DAMMATAN}

# 6 throat letters (huruf al-halq) for Idhaar
_THROAT_LETTERS = {
    "\u0621",  # ء hamza (standalone)
    "\u0623",  # أ alef with hamza above
    "\u0625",  # إ alef with hamza below
    "\u0624",  # ؤ waw with hamza
    "\u0626",  # ئ ya with hamza
    "\u0647",  # هـ ha
    "\u0639",  # ع ain
    "\u062D",  # ح haa
    "\u063A",  # غ ghain
    "\u062E",  # خ kha
}


def detect_idhaar(text):
    """Detect Idhaar (clear pronunciation) of Noon Sakinah or Tanween before throat letters.

    Idhaar applies when Noon Sakinah (noon + sukun) or Tanween (fathatan/kasratan/dammatan)
    is followed by one of the 6 throat letters: ء هـ ع ح غ خ.
    The noon/tanween is pronounced clearly without nasalization or merging.

    Returns a list of annotation dicts with codepoint-based indices.
    """
    chars = list(text)
    annotations = []

    for i, ch in enumerate(chars):
        # Case 1: Noon Sakinah (noon followed by sukun)
        if ch == _NOON:
            marks = get_marks(chars, i)
            mark_set = set(marks)
            if _SUKUN not in mark_set:
                continue
            # Find next base letter after noon + its marks
            j = i + 1 + len(marks)
            next_base = get_next_base(chars, j)
            if next_base in _THROAT_LETTERS:
                end = i + 1 + len(marks)
                annotations.append({"rule": "z", "start": i, "end": end})

        # Case 2: Tanween on any base letter
        elif unicodedata.category(ch).startswith("L"):
            marks = get_marks(chars, i)
            mark_set = set(marks)
            if not (mark_set & _TANWEEN):
                continue
            # Find next base letter after this letter + its marks
            j = i + 1 + len(marks)
            # Skip orthographic alef after fathatan (ًا is a spelling convention)
            if _FATHATAN in mark_set and j < len(chars) and chars[j] == _ALEF:
                j += 1
            next_base = get_next_base(chars, j)
            if next_base in _THROAT_LETTERS:
                # Annotate just the tanween mark(s), not the base letter
                # Find the position of the tanween mark within the marks
                for k, mark in enumerate(marks):
                    if mark in _TANWEEN:
                        ann_start = i + 1 + k
                        ann_end = ann_start + 1
                        annotations.append({"rule": "z", "start": ann_start, "end": ann_end})
                        break

    return annotations


def validate_annotations(surah, ayah, text, annotations):
    """Validate all annotation ranges are within text bounds (grapheme clusters)."""
    text_len = grapheme_len(text)
    errors = []
    for ann in annotations:
        if ann["start"] < 0:
            errors.append(f"  {surah}:{ayah} {ann['rule']} start={ann['start']} < 0")
        if ann["end"] > text_len:
            errors.append(f"  {surah}:{ayah} {ann['rule']} end={ann['end']} > text_len={text_len}")
        if ann["start"] >= ann["end"]:
            errors.append(f"  {surah}:{ayah} {ann['rule']} start={ann['start']} >= end={ann['end']}")
    return errors


def build():
    print("Loading Tanzil text...")
    tanzil_verses = load_tanzil_text()
    print(f"  {len(tanzil_verses)} verses loaded")

    print("Loading tajweed annotations...")
    tajweed_annotations = load_tajweed_annotations()
    print(f"  {len(tajweed_annotations)} verse entries loaded")

    basmala = detect_basmala(tanzil_verses)
    print(f"  Basmala: {basmala!r} ({len(basmala)} chars)")

    # Build output structure
    output = {}
    total_annotations = 0
    total_dropped = 0
    rule_counts = Counter()
    validation_errors = []

    # Sort by surah, ayah
    for (surah, ayah) in sorted(tanzil_verses.keys()):
        text = tanzil_verses[(surah, ayah)]
        annotations = tajweed_annotations.get((surah, ayah), [])

        # Strip basmala from ayah 1 of surahs 2-114, except 9
        chars_removed = 0
        if ayah == 1 and surah != 1 and surah != 9:
            original_len = len(annotations)
            text, chars_removed = strip_basmala(text, basmala)
            annotations = adjust_annotations(annotations, chars_removed)
            dropped = original_len - len(annotations)
            total_dropped += dropped

        # Map cpfair rule names to TajweedRule rawValues
        for ann in annotations:
            ann["rule"] = RULE_MAP.get(ann["rule"], ann["rule"])

        # Detect Lam al-Jalalah (second lam in Allah) — codepoint indices
        lam_jalalah = detect_lam_jalalah(text)
        annotations.extend(lam_jalalah)

        # Detect Ra Tafkheem / Tarqeeq — codepoint indices
        ra_rules = detect_ra_rules(text)
        annotations.extend(ra_rules)

        # Detect Idhaar (Noon Sakinah / Tanween before throat letters) — codepoint indices
        idhaar_rules = detect_idhaar(text)
        annotations.extend(idhaar_rules)

        # Convert codepoint indices to grapheme cluster indices (Swift String.count)
        if annotations:
            annotations = to_grapheme_indices(text, annotations)

        # Validate
        errors = validate_annotations(surah, ayah, text, annotations)
        validation_errors.extend(errors)

        # Count rules
        for ann in annotations:
            rule_counts[ann["rule"]] += 1
        total_annotations += len(annotations)

        # Add to output
        surah_key = str(surah)
        if surah_key not in output:
            output[surah_key] = []

        entry = {"id": ayah, "text": text}
        if annotations:
            entry["annotations"] = annotations
        else:
            entry["annotations"] = []
        output[surah_key].append(entry)

    # Report
    total_verses = sum(len(v) for v in output.values())
    print(f"\nOutput: {total_verses} verses, {total_annotations} annotations")
    print(f"  Basmala annotations dropped: {total_dropped}")

    if validation_errors:
        print(f"\nVALIDATION ERRORS ({len(validation_errors)}):")
        for err in validation_errors[:20]:
            print(err)
        if len(validation_errors) > 20:
            print(f"  ... and {len(validation_errors) - 20} more")
        sys.exit(1)

    print("\nRule distribution:")
    for rule, count in rule_counts.most_common():
        print(f"  {rule}: {count}")

    # Write output
    os.makedirs(OUTPUT_PATH.parent, exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))

    size_mb = OUTPUT_PATH.stat().st_size / (1024 * 1024)
    print(f"\nWritten: {OUTPUT_PATH} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    build()
