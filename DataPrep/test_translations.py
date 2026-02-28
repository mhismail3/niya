#!/usr/bin/env python3
"""Validate translation data files."""
import json
import os
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "..", "Niya", "Resources", "Data")
EXPECTED_VERSES = 6236


class TestTranslations(unittest.TestCase):

    def setUp(self):
        index_path = os.path.join(DATA_DIR, "translations_index.json")
        if not os.path.exists(index_path):
            self.skipTest("translations_index.json not found — run fetch + build first")
        with open(index_path, "r", encoding="utf-8") as f:
            self.index = json.load(f)

    def test_index_has_entries(self):
        self.assertGreaterEqual(len(self.index), 13)

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


if __name__ == "__main__":
    unittest.main()
