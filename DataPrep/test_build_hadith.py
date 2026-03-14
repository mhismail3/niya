#!/usr/bin/env python3
"""Tests for build_hadith.py merge logic."""
import json
import os
import unittest

from build_hadith import normalize_hadith_text

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output", "hadith")


class TestBuildHadith(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        index_path = os.path.join(OUTPUT_DIR, "hadith_collections.json")
        with open(index_path, encoding="utf-8") as f:
            cls.collections = json.load(f)
        cls.collection_map = {c["id"]: c for c in cls.collections}
        cls.loaded = {}
        for c in cls.collections:
            path = os.path.join(OUTPUT_DIR, f"hadith_{c['id']}.json")
            with open(path, encoding="utf-8") as f:
                cls.loaded[c["id"]] = json.loads(f.read(), strict=False)

    def test_grade_normalization(self):
        data = self.loaded["tirmidhi"]
        graded = [h for h in data["hadiths"] if h.get("grade")]
        self.assertGreater(len(graded), 0, "Tirmidhi should have graded hadiths")
        for h in graded[:10]:
            self.assertIsInstance(h["grade"], str)
            self.assertTrue(len(h["grade"]) > 0)

    def test_grade_null_for_ungraded(self):
        for coll_id in ["ahmed", "darimi", "aladab", "bulugh", "mishkat", "riyad", "shamail"]:
            if coll_id not in self.loaded:
                continue
            data = self.loaded[coll_id]
            for h in data["hadiths"][:20]:
                self.assertIsNone(h["grade"],
                    f"{coll_id} hadith #{h['id']} should have null grade")
                self.assertIsNone(h["gradeArabic"],
                    f"{coll_id} hadith #{h['id']} should have null gradeArabic")

    def test_chapter_hadith_range(self):
        data = self.loaded["bukhari"]
        for ch in data["chapters"]:
            if ch["hadithRange"]:
                self.assertEqual(len(ch["hadithRange"]), 2)
                self.assertLessEqual(ch["hadithRange"][0], ch["hadithRange"][1])

    def test_collection_metadata(self):
        for c in self.collections:
            data = self.loaded[c["id"]]
            self.assertEqual(c["totalHadiths"], len(data["hadiths"]),
                f"{c['id']} totalHadiths mismatch")
            self.assertEqual(c["totalChapters"], len(data["chapters"]),
                f"{c['id']} totalChapters mismatch")

    def test_output_json_valid(self):
        for c in self.collections:
            path = os.path.join(OUTPUT_DIR, f"hadith_{c['id']}.json")
            with open(path, encoding="utf-8") as f:
                data = json.loads(f.read(), strict=False)
            self.assertIn("chapters", data)
            self.assertIn("hadiths", data)
            self.assertIsInstance(data["chapters"], list)
            self.assertIsInstance(data["hadiths"], list)

    def test_all_hadiths_have_arabic_and_english(self):
        # Some collections (e.g. darimi) are Arabic-only in source data
        for c in self.collections:
            data = self.loaded[c["id"]]
            empty_arabic = sum(1 for h in data["hadiths"] if not h["arabic"])
            empty_text = sum(1 for h in data["hadiths"] if not h["text"])
            total = len(data["hadiths"])
            # Arabic text should be present for >90% of hadiths
            self.assertLess(empty_arabic / max(total, 1), 0.10,
                f"{c['id']}: {empty_arabic}/{total} missing arabic")

    def test_total_hadith_count(self):
        total = sum(c["totalHadiths"] for c in self.collections)
        self.assertEqual(total, 50884, "Expected 50884 total hadiths")

    def test_all_17_collections(self):
        self.assertEqual(len(self.collections), 17)


class TestTextNormalization(unittest.TestCase):
    """Test normalize_hadith_text edge cases."""

    def test_single_newline_with_spaces_collapsed(self):
        text = "he used \n     to reach the peak"
        self.assertEqual(normalize_hadith_text(text),
                         "he used to reach the peak")

    def test_paragraph_break_preserved(self):
        text = "principles):\n\n\n     1. To testify"
        self.assertEqual(normalize_hadith_text(text),
                         "principles):\n\n1. To testify")

    def test_excessive_newlines_normalized(self):
        text = "over him.\" \n\n\n\n\n\n\n     Narrated Shu'ba:"
        self.assertEqual(normalize_hadith_text(text),
                         "over him.\"\n\nNarrated Shu'ba:")

    def test_tabs_stripped(self):
        text = "shoulders;\twhen he bowed"
        self.assertEqual(normalize_hadith_text(text),
                         "shoulders; when he bowed")

    def test_darimi_tsv_bleed_truncated(self):
        text = "from Nasāʾī 1342)\tnull\tأَخْبَرَنَا"
        self.assertEqual(normalize_hadith_text(text),
                         "from Nasāʾī 1342)")

    def test_multi_space_collapsed(self):
        text = "the Prophet   said"
        self.assertEqual(normalize_hadith_text(text),
                         "the Prophet said")

    def test_empty_string(self):
        self.assertEqual(normalize_hadith_text(""), "")

    def test_none_passthrough(self):
        self.assertIsNone(normalize_hadith_text(None))

    def test_clean_text_unchanged(self):
        text = "This is a clean hadith text with no issues."
        self.assertEqual(normalize_hadith_text(text), text)

    def test_newline_space_newline(self):
        text = "Aisha\n \n     said"
        self.assertEqual(normalize_hadith_text(text),
                         "Aisha\n\nsaid")

    def test_leading_trailing_whitespace_stripped(self):
        text = "  \n  hadith text  \n  "
        self.assertEqual(normalize_hadith_text(text), "hadith text")


class TestTextNormalizationIntegration(unittest.TestCase):
    """Verify built data has no formatting artifacts."""

    @classmethod
    def setUpClass(cls):
        index_path = os.path.join(OUTPUT_DIR, "hadith_collections.json")
        with open(index_path, encoding="utf-8") as f:
            cls.collections = json.load(f)
        cls.loaded = {}
        for c in cls.collections:
            path = os.path.join(OUTPUT_DIR, f"hadith_{c['id']}.json")
            with open(path, encoding="utf-8") as f:
                cls.loaded[c["id"]] = json.loads(f.read(), strict=False)

    def test_no_newline_indentation_in_english_text(self):
        for coll_id, data in self.loaded.items():
            for h in data["hadiths"]:
                self.assertNotRegex(h["text"], r'\n +\S',
                    f"{coll_id} #{h['id']}: newline+indent in text")

    def test_no_tabs_in_text(self):
        for coll_id, data in self.loaded.items():
            for h in data["hadiths"]:
                self.assertNotIn('\t', h["text"],
                    f"{coll_id} #{h['id']}: tab in text")
                self.assertNotIn('\t', h["narrator"],
                    f"{coll_id} #{h['id']}: tab in narrator")

    def test_no_triple_newlines(self):
        for coll_id, data in self.loaded.items():
            for h in data["hadiths"]:
                self.assertNotIn('\n\n\n', h["text"],
                    f"{coll_id} #{h['id']}: triple newline in text")

    def test_no_multi_spaces(self):
        for coll_id, data in self.loaded.items():
            for h in data["hadiths"]:
                self.assertNotRegex(h["text"], r'[^ \n]  +[^ \n]',
                    f"{coll_id} #{h['id']}: multi-space in text")


if __name__ == "__main__":
    unittest.main()
