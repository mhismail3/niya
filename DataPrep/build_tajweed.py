#!/usr/bin/env python3
"""Build tajweed_hafs.json from cpfair/quran-tajweed annotations + Hafs display text.

Reads:
  - source/tajweed/tanzil_uthmani.txt          (Tanzil Uthmanic Hafs text, pipe-delimited)
  - source/tajweed/tajweed.hafs.uthmani-pause-sajdah.json  (character-level annotations)
  - ../Niya/Resources/Data/verses_hafs.json    (Hafs display text — the exact text the app renders)

Writes:
  - ../Niya/Resources/Data/tajweed_hafs.json

Annotations are mapped from Tanzil text to the Hafs display text AT BUILD TIME.
The output stores the Hafs display text + correctly-indexed annotations, so the app
needs NO runtime text alignment — annotations are applied directly.

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
HAFS_PATH = SCRIPT_DIR.parent / "Niya" / "Resources" / "Data" / "verses_hafs.json"

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


def load_hafs_text():
    """Load Hafs display text from verses_hafs.json."""
    with open(HAFS_PATH, encoding="utf-8") as f:
        data = json.load(f)
    verses = {}
    for surah_key, verse_list in data.items():
        surah = int(surah_key)
        for v in verse_list:
            verses[(surah, v["id"])] = v["text"]
    return verses


def clean_arabic_text(text):
    """Mirror TajweedService.cleanArabicText — same substitutions as Swift."""
    return (text
            .replace("\u06DF", "\u06E0")
            .replace("\u0672", "\u0670")
            .replace("\u066E", "\u0649"))


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
    """Adjust annotation indices after stripping a prefix."""
    if chars_removed == 0:
        return annotations

    adjusted = []
    for ann in annotations:
        start = ann["start"]
        end = ann["end"]

        if end <= chars_removed:
            continue

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


# ---------------------------------------------------------------------------
# Cross-text annotation mapping (Tanzil → Hafs)
# ---------------------------------------------------------------------------

def _base_letter(ch):
    """Extract base Arabic letter scalar value, normalizing hamza carriers."""
    if ch == " ":
        return 0x0020
    v = ord(ch)
    cat = unicodedata.category(ch)
    if cat == "Lo" and v != 0x0640:  # Letter, Other (skip tatweel)
        if v in (0x0623, 0x0625):
            return 0x0621  # hamza carriers → base hamza
        if v == 0x0649:
            return 0x064A  # alef maksura → yeh
        return v
    return None


def map_annotations_cross_text(annotations, src_text, tgt_text):
    """Map codepoint-based annotations from src_text to tgt_text positions.

    Uses base-letter alignment: walks both texts matching Arabic base letters
    1:1 while allowing diacritics, waqf marks, and whitespace to differ.
    Builds a position map from every source codepoint to its corresponding
    target codepoint, then translates each annotation range.
    """
    if src_text == tgt_text:
        return annotations

    src = list(src_text)
    tgt = list(tgt_text)

    # Build base-letter sequences for alignment
    src_bases = []  # [(cp_index, base_letter_value)]
    for i, ch in enumerate(src):
        b = _base_letter(ch)
        if b is not None:
            src_bases.append((i, b))

    tgt_bases = []
    for i, ch in enumerate(tgt):
        b = _base_letter(ch)
        if b is not None:
            tgt_bases.append((i, b))

    # Match base letters 1:1
    base_map = {}  # src_cp_index → tgt_cp_index (for base letters)
    ti = 0
    for si_idx, (si_cp, si_val) in enumerate(src_bases):
        while ti < len(tgt_bases):
            _, ti_val = tgt_bases[ti]
            if ti_val == si_val:
                base_map[si_cp] = tgt_bases[ti][0]
                ti += 1
                break
            # Allow skipping up to 3 unmatched target letters (waqf marks, extra chars)
            if ti + 1 < len(tgt_bases) and tgt_bases[ti + 1][1] == si_val:
                ti += 1
                continue
            if ti + 2 < len(tgt_bases) and tgt_bases[ti + 2][1] == si_val:
                ti += 2
                continue
            # No match — skip this source letter
            break

    # Build full codepoint position map (including marks between base letters)
    # For each source codepoint, find the nearest mapped base letter position
    pos_map = [len(tgt)] * (len(src) + 1)

    # Forward-fill from mapped base letters
    last_tgt_pos = 0
    for si in range(len(src)):
        if si in base_map:
            last_tgt_pos = base_map[si]
            pos_map[si] = last_tgt_pos
        else:
            # For combining marks: they belong to the same grapheme cluster
            # as the preceding base letter, so map to the same target position
            pos_map[si] = last_tgt_pos
    pos_map[len(src)] = len(tgt)

    # For annotation end positions, we need the position AFTER the last
    # mapped character. Walk the base_map to find the next base letter
    # position for end-of-range calculations.
    def target_end_for(src_end):
        """Find target position corresponding to source end (exclusive)."""
        if src_end >= len(src):
            return len(tgt)
        if src_end in base_map:
            return base_map[src_end]
        # src_end is a combining mark — find the next base letter in target
        # by looking at where the next source base letter maps
        for j in range(src_end, len(src)):
            if j in base_map:
                return base_map[j]
        return len(tgt)

    # Translate annotations
    result = []
    for ann in annotations:
        s = pos_map[ann["start"]] if ann["start"] < len(pos_map) else len(tgt)
        e = target_end_for(ann["end"])

        # Ensure the range covers at least the grapheme cluster of the start position
        if s >= e and s < len(tgt):
            # Expand to cover the base letter + its combining marks
            e = s + 1
            while e < len(tgt) and unicodedata.category(tgt[e]).startswith("M"):
                e += 1

        if s < e and e <= len(tgt):
            result.append({"rule": ann["rule"], "start": s, "end": e})

    return result


# ---------------------------------------------------------------------------
# Custom rule detection (runs against Hafs display text)
# ---------------------------------------------------------------------------

# Pattern: lam + lam + shadda + fatha + ha (the word Allah in Uthmanic script)
ALLAH_PATTERN = re.compile("\u0644\u0644\u0651\u064e\u0647")


def detect_lam_jalalah(text):
    """Detect Lam al-Jalalah in the word Allah and return annotations.

    Covers both lams + shadda + fatha: the two lams form a ligature
    in the Uthmanic font, so both must share the color attribute for
    CoreText to color the entire glyph.
    Returns a list of annotation dicts with codepoint-based indices.
    """
    annotations = []
    for m in ALLAH_PATTERN.finditer(text):
        first_lam_cp = m.start()
        fatha_cp = m.start() + 3
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
    """Walk backward from index i to find the preceding base letter's vowel marks."""
    j = i - 1
    while j >= 0 and unicodedata.category(chars[j]).startswith("M"):
        j -= 1
    while j >= 0 and not unicodedata.category(chars[j]).startswith("L"):
        j -= 1
    if j < 0:
        return [], None
    base_char = chars[j]
    return get_marks(chars, j), base_char


def get_next_base(chars, start):
    """Find the next base letter after index start."""
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

# Hafs text uses a different sukun variant
_SUKUN_HAFS = "\u06E1"

_HEAVY_VOWELS = {_FATHA, _FATHATAN, _DAMMA, _DAMMATAN}
_LIGHT_VOWELS = {_KASRA, _KASRATAN}

# Hafs text uses alternate tanween marks — include them
_HAFS_FATHATAN = "\u0657"  # Arabic Inverted Damma (used as fathatan in some Hafs texts)
_HAFS_DAMMATAN = "\u065E"  # Arabic Fatha With Two Dots (used as dammatan)
_HAFS_KASRATAN = "\u0656"  # Arabic Subscript Alef (used as kasratan)

_HEAVY_VOWELS_HAFS = _HEAVY_VOWELS | {_HAFS_FATHATAN, _HAFS_DAMMATAN}
_LIGHT_VOWELS_HAFS = _LIGHT_VOWELS | {_HAFS_KASRATAN}

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

# Long vowel letters
_ALEF = "\u0627"
_ALEF_WASLA = "\u0671"
_WAW = "\u0648"
_YA = "\u064A"


def classify_ra(chars, i):
    """Classify Ra at codepoint index i. Returns 'r' (tafkheem), 'e' (tarqeeq), or None."""
    marks = get_marks(chars, i)
    mark_set = set(marks)

    has_shadda = _SHADDA in mark_set
    has_sukun = _SUKUN in mark_set or _SUKUN_HAFS in mark_set

    if not has_sukun:
        if mark_set & _HEAVY_VOWELS_HAFS:
            return "r"
        if mark_set & _LIGHT_VOWELS_HAFS:
            return "e"
        if _SUPERSCRIPT_ALEF in mark_set:
            return "r"
        if has_shadda:
            return "r"
        if not marks:
            return None
        return None

    prev_marks, prev_base = get_preceding_vowel(chars, i)
    prev_mark_set = set(prev_marks)

    if prev_mark_set & {_FATHA, _FATHATAN, _HAFS_FATHATAN}:
        return "r"
    if prev_mark_set & {_DAMMA, _DAMMATAN, _HAFS_DAMMATAN}:
        return "r"
    if _SHADDA in prev_mark_set and prev_mark_set & (_HEAVY_VOWELS_HAFS):
        return "r"

    if prev_mark_set & _LIGHT_VOWELS_HAFS or (_SHADDA in prev_mark_set and prev_mark_set & _LIGHT_VOWELS_HAFS):
        j = i + 1 + len(marks)
        next_base = get_next_base(chars, j)
        if next_base in _ISTILA_LETTERS:
            return "r"
        return "e"

    if prev_base in (_ALEF, _ALEF_WASLA):
        return "r"
    if prev_base == _YA:
        return "e"
    if prev_base == _WAW:
        return "r"

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

# Tanween marks (including Hafs variants)
_TANWEEN = {_FATHATAN, _KASRATAN, _DAMMATAN}
_TANWEEN_HAFS = _TANWEEN | {_HAFS_FATHATAN, _HAFS_DAMMATAN, _HAFS_KASRATAN}

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
    """Detect Idhaar of Noon Sakinah or Tanween before throat letters."""
    chars = list(text)
    annotations = []

    for i, ch in enumerate(chars):
        # Case 1: Noon Sakinah
        if ch == _NOON:
            marks = get_marks(chars, i)
            mark_set = set(marks)
            if _SUKUN not in mark_set and _SUKUN_HAFS not in mark_set:
                continue
            j = i + 1 + len(marks)
            next_base = get_next_base(chars, j)
            if next_base in _THROAT_LETTERS:
                end = i + 1 + len(marks)
                annotations.append({"rule": "z", "start": i, "end": end})

        # Case 2: Tanween on any base letter
        elif unicodedata.category(ch).startswith("L"):
            marks = get_marks(chars, i)
            mark_set = set(marks)
            if not (mark_set & _TANWEEN_HAFS):
                continue
            j = i + 1 + len(marks)
            if (mark_set & {_FATHATAN, _HAFS_FATHATAN}) and j < len(chars) and chars[j] == _ALEF:
                j += 1
            next_base = get_next_base(chars, j)
            if next_base in _THROAT_LETTERS:
                # Annotate the full letter + its marks (not just the tanween mark)
                end = i + 1 + len(marks)
                annotations.append({"rule": "z", "start": i, "end": end})

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

    print("Loading Hafs display text...")
    hafs_verses = load_hafs_text()
    print(f"  {len(hafs_verses)} verses loaded")

    print("Loading tajweed annotations...")
    tajweed_annotations = load_tajweed_annotations()
    print(f"  {len(tajweed_annotations)} verse entries loaded")

    basmala = detect_basmala(tanzil_verses)
    print(f"  Basmala: {basmala!r} ({len(basmala)} chars)")

    # Build output structure
    output = {}
    total_annotations = 0
    total_dropped = 0
    total_mapped = 0
    rule_counts = Counter()
    validation_errors = []

    for (surah, ayah) in sorted(tanzil_verses.keys()):
        tanzil_text = tanzil_verses[(surah, ayah)]
        annotations = tajweed_annotations.get((surah, ayah), [])

        # Strip basmala from ayah 1 of surahs 2-114, except 9
        chars_removed = 0
        if ayah == 1 and surah != 1 and surah != 9:
            original_len = len(annotations)
            tanzil_text, chars_removed = strip_basmala(tanzil_text, basmala)
            annotations = adjust_annotations(annotations, chars_removed)
            dropped = original_len - len(annotations)
            total_dropped += dropped

        # Map cpfair rule names to TajweedRule rawValues
        for ann in annotations:
            ann["rule"] = RULE_MAP.get(ann["rule"], ann["rule"])

        # Get the Hafs display text (what the app actually renders)
        hafs_text = hafs_verses.get((surah, ayah), "")
        display_text = clean_arabic_text(hafs_text)

        if not display_text:
            print(f"WARNING: No Hafs text for {surah}:{ayah}")
            continue

        # Map cpfair annotations from Tanzil codepoint positions to Hafs codepoint positions
        if annotations:
            annotations = map_annotations_cross_text(annotations, tanzil_text, display_text)
            total_mapped += len(annotations)

        # Detect custom rules directly against the Hafs display text (codepoint indices)
        lam_jalalah = detect_lam_jalalah(display_text)
        annotations.extend(lam_jalalah)

        ra_rules = detect_ra_rules(display_text)
        annotations.extend(ra_rules)

        idhaar_rules = detect_idhaar(display_text)
        annotations.extend(idhaar_rules)

        # Convert codepoint indices to grapheme cluster indices against display text
        if annotations:
            annotations = to_grapheme_indices(display_text, annotations)

        # Validate against display text
        errors = validate_annotations(surah, ayah, display_text, annotations)
        validation_errors.extend(errors)

        for ann in annotations:
            rule_counts[ann["rule"]] += 1
        total_annotations += len(annotations)

        # Store display text + annotations
        surah_key = str(surah)
        if surah_key not in output:
            output[surah_key] = []

        entry = {"id": ayah, "text": display_text}
        if annotations:
            entry["annotations"] = annotations
        else:
            entry["annotations"] = []
        output[surah_key].append(entry)

    # Report
    total_verses = sum(len(v) for v in output.values())
    print(f"\nOutput: {total_verses} verses, {total_annotations} annotations")
    print(f"  Basmala annotations dropped: {total_dropped}")
    print(f"  Cross-text mapped annotations: {total_mapped}")

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
