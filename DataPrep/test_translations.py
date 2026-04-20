#!/usr/bin/env python3
"""Validate translation data files."""
import json
import os
import re
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "..", "Niya", "Resources", "Data")
EXPECTED_VERSES = 6236

REQUIRED_EDITION_IDS = {
    "ps_abdulwali", "ps_rwwad",
    "fa_makarem", "fa_fooladvand",
    "it_piccardo",
    "el_rwwad",
}

EXPECTED_LANGUAGE_COUNTS = {"ps": 2, "fa": 2, "it": 1, "el": 1}

# Unicode block ranges for spot-checking that text is in the expected script.
SCRIPT_RANGES = {
    "arabic": (0x0600, 0x06FF),   # ps, fa
    "latin":  (0x0041, 0x024F),   # it
    "greek":  (0x0370, 0x03FF),   # el
}

EDITION_SCRIPT = {
    "ps_abdulwali":   "arabic",
    "ps_rwwad":       "arabic",
    "fa_makarem":     "arabic",
    "fa_fooladvand":  "arabic",
    "it_piccardo":    "latin",
    "el_rwwad":       "greek",
}

HTML_TAG_RE = re.compile(r"<[a-zA-Z/][^>]*>")
HTML_ENTITY_RE = re.compile(r"&#\d+;|&[a-zA-Z]+;")


def _in_range(ch, lo, hi):
    return lo <= ord(ch) <= hi


class TestTranslations(unittest.TestCase):

    def setUp(self):
        index_path = os.path.join(DATA_DIR, "translations_index.json")
        if not os.path.exists(index_path):
            self.skipTest("translations_index.json not found — run fetch + build first")
        with open(index_path, "r", encoding="utf-8") as f:
            self.index = json.load(f)

    def test_index_has_entries(self):
        self.assertGreaterEqual(len(self.index), 20)

    def test_index_fields(self):
        required = {"id", "language", "languageName", "name", "author", "filename"}
        for entry in self.index:
            self.assertTrue(required.issubset(entry.keys()), f"Missing fields in {entry.get('id')}")

    def test_each_translation_file_exists(self):
        for entry in self.index:
            path = os.path.join(DATA_DIR, entry["filename"])
            self.assertTrue(os.path.exists(path), f"Missing: {entry['filename']}")

    def test_each_translation_has_6236_verses(self):
        for entry in self.index:
            path = os.path.join(DATA_DIR, entry["filename"])
            if not os.path.exists(path):
                continue
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.assertEqual(len(data), EXPECTED_VERSES,
                             f"{entry['id']}: expected {EXPECTED_VERSES}, got {len(data)}")

    def test_no_empty_translations(self):
        for entry in self.index:
            path = os.path.join(DATA_DIR, entry["filename"])
            if not os.path.exists(path):
                continue
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            empty = [k for k, v in data.items() if not v.strip()]
            self.assertEqual(len(empty), 0,
                             f"{entry['id']}: {len(empty)} empty translations")

    def test_valid_json(self):
        for entry in self.index:
            path = os.path.join(DATA_DIR, entry["filename"])
            if not os.path.exists(path):
                continue
            with open(path, "r", encoding="utf-8") as f:
                try:
                    json.load(f)
                except json.JSONDecodeError as e:
                    self.fail(f"{entry['id']}: invalid JSON — {e}")

    def test_index_matches_files(self):
        index_filenames = {e["filename"] for e in self.index}
        actual_files = {f for f in os.listdir(DATA_DIR)
                        if f.startswith("translation_") and f.endswith(".json")}
        self.assertEqual(index_filenames, actual_files,
                         f"Index/files mismatch. Extra: {actual_files - index_filenames}, "
                         f"Missing: {index_filenames - actual_files}")

    def test_required_edition_ids_present(self):
        ids = {e["id"] for e in self.index}
        missing = REQUIRED_EDITION_IDS - ids
        self.assertFalse(missing, f"Missing required editions: {sorted(missing)}")

    def test_required_languages_present(self):
        counts = {}
        for entry in self.index:
            counts[entry["language"]] = counts.get(entry["language"], 0) + 1
        for lang, expected in EXPECTED_LANGUAGE_COUNTS.items():
            self.assertGreaterEqual(
                counts.get(lang, 0), expected,
                f"Language {lang}: expected at least {expected} edition(s), got {counts.get(lang, 0)}",
            )

    def test_translation_text_uses_expected_script(self):
        for entry in self.index:
            tid = entry["id"]
            if tid not in EDITION_SCRIPT:
                continue
            script = EDITION_SCRIPT[tid]
            lo, hi = SCRIPT_RANGES[script]
            path = os.path.join(DATA_DIR, entry["filename"])
            if not os.path.exists(path):
                continue
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            sample = data.get("1:2") or data.get("1:1") or ""
            hits = sum(1 for ch in sample if _in_range(ch, lo, hi))
            self.assertGreater(
                hits, 0,
                f"{tid}: '1:2'='{sample[:60]}' contains no characters in {script} block",
            )

    def test_no_html_residue(self):
        # All bundled editions must be free of stray <html> tags and entities.
        # fetch_translations.py normalises on fetch; this is the regression guard.
        for entry in self.index:
            path = os.path.join(DATA_DIR, entry["filename"])
            if not os.path.exists(path):
                continue
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            tag_offenders = [k for k, v in data.items() if HTML_TAG_RE.search(v)]
            ent_offenders = [k for k, v in data.items() if HTML_ENTITY_RE.search(v)]
            self.assertFalse(
                tag_offenders,
                f"{entry['id']}: HTML tags found in {len(tag_offenders)} verses (e.g. {tag_offenders[:3]})",
            )
            self.assertFalse(
                ent_offenders,
                f"{entry['id']}: HTML entities found in {len(ent_offenders)} verses (e.g. {ent_offenders[:3]})",
            )


if __name__ == "__main__":
    unittest.main()
