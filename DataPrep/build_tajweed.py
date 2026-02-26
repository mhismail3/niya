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
import sys
from collections import Counter
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
SOURCE_DIR = SCRIPT_DIR / "source" / "tajweed"
OUTPUT_PATH = SCRIPT_DIR.parent / "Niya" / "Resources" / "Data" / "tajweed_hafs.json"

TANZIL_PATH = SOURCE_DIR / "tanzil_uthmani.txt"
TAJWEED_PATH = SOURCE_DIR / "tajweed.hafs.uthmani-pause-sajdah.json"


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


def strip_basmala(text, basmala):
    """Strip basmala prefix + trailing space from text. Returns (stripped_text, chars_removed)."""
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
        # Check if char after basmala is whitespace
        next_char = text[len(basmala)]
        if next_char in (" ", "\u2009", "\u200b", "\u00a0"):
            offset = len(basmala) + 1
            return text[offset:], offset

    # Fallback: try matching just the basmala with no separator
    if text.startswith(basmala):
        return text[len(basmala):], len(basmala)

    # Could not strip — warn and return original
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


def validate_annotations(surah, ayah, text, annotations):
    """Validate all annotation ranges are within text bounds."""
    text_len = len(text)
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
