#!/usr/bin/env python3
"""
build_root_meanings.py — Build root_meanings.json from Quranic Arabic Corpus dictionary data.

Source: islamAndAi/QURAN-NLP (Apache-2.0), data from corpus.quran.com (GNU GPL)
The dictionary CSV contains per-word entries grouped by root, with POS + English definitions.

For each root, produces a list of meaning entries like:
  {"pos": "Verb (form I)", "def": "to have mercy"}
  {"pos": "Noun", "def": "mercy, womb, kinship"}

Usage:
    python3 DataPrep/build_root_meanings.py
"""

import csv
import json
import os
import re
import subprocess
from collections import Counter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "root_meanings.json")
MORPH_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "word_morphology.json")

REPO_URL = "https://github.com/islamAndAi/QURAN-NLP.git"
REPO_DIR = os.path.join(SCRIPT_DIR, "source", "QURAN-NLP")
DICT_CSV = os.path.join(REPO_DIR, "data", "quran", "corpus", "quran_dictionary.csv")

# Noise words/patterns to strip from translations when deriving noun meanings
STRIP_RE = re.compile(
    r"^\s*\(?(?:the|a|an|and|of|for|to|in|by|with|from|its|his|her|your|my|our|their|"
    r"but|as|is|are|was|were|be|been|has|had|have|shall|will|may|can|do|did|does|"
    r"that|which|who|whom|this|these|those|it|he|she|they|we|you|I|me|him|us|them|"
    r"not|no|nor|so|if|or|on|at|into|upon|about|against|between|through|"
    r"surely|indeed|certainly|verily|truly)\)?\s+",
    re.IGNORECASE,
)


def ensure_repo():
    if os.path.exists(DICT_CSV):
        print(f"  Using cached: {DICT_CSV}")
        return
    print(f"  Cloning: {REPO_URL}")
    subprocess.run(
        ["git", "clone", "--depth", "1", REPO_URL, REPO_DIR],
        check=True, capture_output=True,
    )


def normalize_translation(text):
    """Strip articles, pronouns, prepositions, and brackets from a translation."""
    t = text.strip()
    # Remove brackets/parens wrapping
    t = re.sub(r"[\[\]()]", "", t)
    # Strip leading noise words (up to 3 rounds)
    for _ in range(3):
        t2 = STRIP_RE.sub("", t, count=1)
        if t2 == t:
            break
        t = t2
    t = t.strip()
    # Lowercase
    return t.lower() if t else ""


def parse_dictionary():
    """Parse dictionary CSV into root -> structured meanings."""
    # Collect raw entries per root, keyed by (root, subheading)
    root_data = {}

    with open(DICT_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            root = row["title"].replace(" ", "")
            subheading = row["subheading"].strip()
            translation = row["translation"].strip()
            if not root or not subheading:
                continue
            if root not in root_data:
                root_data[root] = {}
            if subheading not in root_data[root]:
                root_data[root][subheading] = []
            root_data[root][subheading].append(translation)

    # Build structured meanings per root
    result = {}
    for root, sub_map in root_data.items():
        meanings = []
        for subheading, translations in sub_map.items():
            if " - " in subheading:
                # Verb/participle with explicit definition: "Verb (form I) - to have mercy"
                pos, definition = subheading.split(" - ", 1)
                meanings.append({"pos": pos.strip(), "def": definition.strip()})
            else:
                # Noun/Adjective/etc — derive meaning from translations
                pos = subheading
                normalized = [normalize_translation(t) for t in translations]
                normalized = [n for n in normalized if n and len(n) > 1]
                if not normalized:
                    continue
                # Pick top unique meanings by frequency
                counts = Counter(normalized)
                top = [word for word, _ in counts.most_common(5)]
                meanings.append({"pos": pos, "def": ", ".join(top)})

        if meanings:
            result[root] = meanings

    return result


def main():
    print("Build root meanings")
    print("=" * 50)

    print("\n1. Ensuring source data...")
    ensure_repo()

    print("\n2. Parsing dictionary...")
    meanings = parse_dictionary()
    print(f"    Roots with meanings: {len(meanings)}")

    # Check coverage against our morphology roots
    if os.path.exists(MORPH_PATH):
        with open(MORPH_PATH, "r", encoding="utf-8") as f:
            morph = json.load(f)
        our_roots = set(morph["roots"].keys())
        covered = our_roots & set(meanings.keys())
        missing = our_roots - set(meanings.keys())
        print(f"    Our roots: {len(our_roots)}, covered: {len(covered)}, missing: {len(missing)}")
        if missing:
            print(f"    Missing: {sorted(missing)}")

    print(f"\n3. Writing {OUTPUT_PATH}...")
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(meanings, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    print(f"    Written: {size_kb:.1f} KB")

    # Show sample entries
    print("\n4. Sample entries:")
    for root in ["كتب", "رحم", "علم", "سمو", "أله"]:
        if root in meanings:
            entries = meanings[root]
            for e in entries[:4]:
                print(f"    {root}: [{e['pos']}] {e['def']}")
            if len(entries) > 4:
                print(f"    {root}: ... +{len(entries) - 4} more")

    print("\nDone!")


if __name__ == "__main__":
    main()
