#!/usr/bin/env python3
"""
build_morphology.py — Parse Quranic Arabic Corpus morphology data and generate word_morphology.json

Source: mustafa0x/quran-morphology (enhanced fork with corrections)
Actual format: location<TAB>arabic_text<TAB>broad_category<TAB>features
  location = surah:verse:word:segment
  features = pipe-separated: POS_TAG|PREF/SUFF|ROOT:xxx|LEM:xxx|gender|number|case|etc.

Usage:
    python3 DataPrep/build_morphology.py              # build word_morphology.json
    python3 DataPrep/build_morphology.py --verify      # build + cross-check with word_data.json
"""

import json
import os
import sys
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "word_morphology.json")
WORD_DATA_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "word_data.json")

CORPUS_URL = "https://raw.githubusercontent.com/mustafa0x/quran-morphology/master/quran-morphology.txt"
CORPUS_CACHE = os.path.join(SCRIPT_DIR, "source", "quran-morphology.txt")

# POS tags that appear as the first feature element
POS_TAGS = {
    "N", "PN", "ADJ", "V", "P", "CONJ", "DET", "REL", "DEM", "PRON",
    "NEG", "INTG", "COND", "RES", "CERT", "EXP", "SUP", "PREV", "ANS",
    "AVR", "INC", "SUR", "VOC", "INL", "EMPH", "T", "LOC", "ACC",
    "IMPV", "PRT", "NV",
    # Noun derivation forms (treated as sub-POS)
    "ACT_PCPL", "PASS_PCPL", "VN",
}

CASE_TAGS = {"NOM", "ACC", "GEN"}
MOOD_TAGS = {"IND", "SUBJ", "JUS"}
GENDER_VALS = {"M", "F"}
NUMBER_VALS = {"S", "D", "P"}
PERSON_VALS = {"1", "2", "3"}
VOICE_VALS = {"ACT", "PASS"}
ASPECT_VALS = {"PERF", "IMPF", "IMPV"}
SKIP_TAGS = {"PREF", "SUFF", "INDEF", "ADJ"}


def download_file(url, cache_path):
    if os.path.exists(cache_path):
        print(f"  Using cached: {cache_path}")
        return cache_path
    print(f"  Downloading: {url}")
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    urllib.request.urlretrieve(url, cache_path)
    return cache_path


def parse_features(feature_str):
    """Parse a pipe-separated feature string into structured data."""
    result = {"pos": None, "root": None, "lemma": None, "features": {},
              "is_prefix": False, "is_suffix": False}

    tags = [t for t in feature_str.split("|") if t]

    for tag in tags:
        if tag == "PREF":
            result["is_prefix"] = True
        elif tag == "SUFF":
            result["is_suffix"] = True
        elif tag.startswith("ROOT:"):
            result["root"] = tag[5:]
        elif tag.startswith("LEM:"):
            result["lemma"] = tag[4:]
        elif tag.startswith("MOOD:"):
            result["features"]["mood"] = tag[5:]
        elif tag.startswith("VF:"):
            vf = tag[3:]
            result["features"]["form"] = vf
        elif tag in POS_TAGS and result["pos"] is None:
            result["pos"] = tag
        elif tag in CASE_TAGS:
            result["features"]["cas"] = tag
        elif tag in MOOD_TAGS:
            result["features"]["mood"] = tag
        elif tag in VOICE_VALS:
            result["features"]["voice"] = tag
        elif tag in ASPECT_VALS:
            result["features"]["aspect"] = tag
        elif tag in SKIP_TAGS or tag == "ADJ":
            pass
        else:
            # Combined gender+number tags like "MS", "MP", "FS", "FP", "MD", "FD"
            # or "1MS", "2MS", "3MS", "1MP", "2MP", "3MP", "1FS", etc.
            decoded = decode_pronoun_tag(tag)
            if decoded:
                result["features"].update(decoded)

    return result


def decode_pronoun_tag(tag):
    """Decode compact pronoun/agreement tags like 2MS, 3FP, MP, FS, 1P etc."""
    if not tag:
        return None

    result = {}
    rest = tag

    # Leading person digit
    if rest and rest[0] in "123":
        result["per"] = rest[0]
        rest = rest[1:]

    # Gender
    if rest and rest[0] in "MF":
        result["gen"] = rest[0]
        rest = rest[1:]

    # Number
    if rest and rest[0] in "SDP":
        result["num"] = rest[0]
        rest = rest[1:]

    if rest:
        return None
    if not result:
        return None
    return result


def parse_corpus(corpus_path):
    """Parse the morphology corpus. Returns words dict keyed by 'surah:verse:position'."""
    segment_data = {}

    with open(corpus_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            parts = line.split("\t")
            if len(parts) < 3:
                continue

            loc = parts[0]
            loc_parts = loc.split(":")
            if len(loc_parts) != 4:
                continue

            s, v, w, seg = int(loc_parts[0]), int(loc_parts[1]), int(loc_parts[2]), int(loc_parts[3])
            # parts[1] = arabic text fragment, parts[2] = broad category (N/V/P)
            # parts[3] = detailed features (if present)
            feature_str = parts[3] if len(parts) > 3 else parts[2]

            parsed = parse_features(feature_str)
            # Use broad category as fallback POS
            broad_cat = parts[2] if len(parts) > 3 else None
            if parsed["pos"] is None and broad_cat in POS_TAGS:
                parsed["pos"] = broad_cat

            key = (s, v, w)
            if key not in segment_data:
                segment_data[key] = []
            segment_data[key].append((seg, parsed))

    # Consolidate segments per word
    words = {}
    for (s, v, w), segments in segment_data.items():
        segments.sort(key=lambda x: x[0])

        # Find stem segment (has root/lemma, not prefix/suffix)
        stem = None
        for seg_num, p in segments:
            if (p["root"] or p["lemma"]) and not p["is_prefix"] and not p["is_suffix"]:
                stem = p
                break
        if stem is None:
            # Try any segment with root/lemma
            for seg_num, p in segments:
                if p["root"] or p["lemma"]:
                    stem = p
                    break
        if stem is None:
            # Use last non-prefix segment
            for seg_num, p in reversed(segments):
                if not p["is_prefix"]:
                    stem = p
                    break
        if stem is None:
            stem = segments[-1][1]

        root = stem["root"]
        lemma = stem["lemma"]
        pos = stem["pos"] or "N"

        # Collect features from all segments, stem priority
        features = {}
        for seg_num, p in segments:
            for k, val in p["features"].items():
                if k not in features:
                    features[k] = val
        # Stem features override
        features.update(stem["features"])

        word_key = f"{s}:{v}:{w}"
        words[word_key] = {
            "root": root,
            "lemma": lemma,
            "pos": pos,
            "features": features,
        }

    return words


def build_root_index(words):
    """Build root -> {freq, refs} index. Refs are deduplicated to unique (surah, verse) pairs."""
    root_refs = {}

    for key, word in words.items():
        root = word.get("root")
        if not root:
            continue
        parts = key.split(":")
        s, v, p = int(parts[0]), int(parts[1]), int(parts[2])
        if root not in root_refs:
            root_refs[root] = []
        root_refs[root].append({"s": s, "v": v, "p": p})

    roots = {}
    for root, refs in root_refs.items():
        seen = set()
        unique_refs = []
        for ref in refs:
            verse_key = (ref["s"], ref["v"])
            if verse_key not in seen:
                seen.add(verse_key)
                unique_refs.append(ref)
        roots[root] = {
            "freq": len(refs),
            "refs": unique_refs,
        }

    return roots


def build_output(words, roots):
    """Build final output dict with compact word entries."""
    out_words = {}
    for key, w in words.items():
        entry = {"pos": w["pos"]}
        if w.get("root"):
            entry["root"] = w["root"]
        if w.get("lemma"):
            entry["lemma"] = w["lemma"]
        feats = w.get("features", {})
        if feats:
            entry["features"] = feats
        out_words[key] = entry

    return {"words": out_words, "roots": roots}


def validate(output, word_data_path=None):
    """Run validation checks."""
    words = output["words"]
    roots = output["roots"]
    total = len(words)

    print(f"\n  Validation:")
    print(f"    Total words: {total}")

    surahs = {int(k.split(":")[0]) for k in words}
    missing = set(range(1, 115)) - surahs
    if missing:
        print(f"    WARNING: Missing surahs: {sorted(missing)}")
    else:
        print(f"    All 114 surahs represented")

    print(f"    Total roots: {len(roots)}")

    no_root = sum(1 for w in words.values() if "root" not in w)
    print(f"    Words without root: {no_root} ({no_root*100/total:.1f}%)")

    # Verify root freq matches actual count
    freq_ok = True
    for root_str, entry in roots.items():
        actual = sum(1 for w in words.values() if w.get("root") == root_str)
        if entry["freq"] != actual:
            freq_ok = False
            break
    print(f"    Root frequencies: {'verified' if freq_ok else 'MISMATCH'}")

    if word_data_path and os.path.exists(word_data_path):
        with open(word_data_path, "r", encoding="utf-8") as f:
            wd = json.load(f)
        wd_count = sum(
            len(vd.get("w", []))
            for sd in wd.values()
            for vd in sd.values()
        )
        print(f"    word_data.json words: {wd_count}")
        diff = abs(total - wd_count)
        pct = diff * 100 / max(total, wd_count) if max(total, wd_count) > 0 else 0
        print(f"    Difference: {diff} words ({pct:.1f}%)")

    if "1:1:1" in words:
        w = words["1:1:1"]
        print(f"    First word (1:1:1): pos={w['pos']}, root={w.get('root')}")


def main():
    verify = "--verify" in sys.argv

    print("Build morphology data")
    print("=" * 50)

    print("\n1. Downloading corpus...")
    corpus_path = download_file(CORPUS_URL, CORPUS_CACHE)

    print("\n2. Parsing corpus...")
    words = parse_corpus(corpus_path)
    print(f"    Parsed {len(words)} words")

    print("\n3. Building root index...")
    roots = build_root_index(words)
    print(f"    Built {len(roots)} root entries")

    print("\n4. Building output...")
    output = build_output(words, roots)

    validate(output, WORD_DATA_PATH if verify else None)

    print(f"\n5. Writing {OUTPUT_PATH}...")
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))

    size_mb = os.path.getsize(OUTPUT_PATH) / (1024 * 1024)
    print(f"    Written: {size_mb:.1f} MB")
    print("\nDone!")


if __name__ == "__main__":
    main()
