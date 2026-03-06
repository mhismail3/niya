#!/usr/bin/env python3
"""Tests for Khattab translation conversion pipeline."""
import html
import json
import os
import re
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_CACHE = os.path.join(SCRIPT_DIR, "output", "mustafakhattab2018.json")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "output", "translations", "translation_en_clearquran.json")

STANDARD_VERSE_COUNTS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99,
    128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35,
    38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11,
    11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40,
    46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8,
    8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
]

# Import normalize_text from fetch_khattab
import importlib.util
spec = importlib.util.spec_from_file_location("fetch_khattab", os.path.join(SCRIPT_DIR, "fetch_khattab.py"))
fetch_khattab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetch_khattab)
normalize_text = fetch_khattab.normalize_text


class TestKhattabSource(unittest.TestCase):
    """Tests that validate the raw source data."""

    @classmethod
    def setUpClass(cls):
        if not os.path.exists(SOURCE_CACHE):
            raise unittest.SkipTest("Source file not downloaded — run fetch_khattab.py first")
        with open(SOURCE_CACHE, "r", encoding="utf-8") as f:
            cls.source = json.load(f)

    def test_source_has_114_surahs(self):
        self.assertEqual(len(self.source), 114)

    def test_source_has_6236_total_verses(self):
        total = sum(len(s.get("Ayahs", {})) for s in self.source.values())
        self.assertEqual(total, 6236)

    def test_source_verse_counts_match_standard(self):
        for i, expected in enumerate(STANDARD_VERSE_COUNTS, 1):
            surah = self.source.get(str(i), {})
            actual = len(surah.get("Ayahs", {}))
            self.assertEqual(actual, expected, f"Surah {i}: expected {expected}, got {actual}")

    def test_no_empty_translations_in_source(self):
        for surah_key, surah_data in self.source.items():
            for verse_key, verse_data in surah_data.get("Ayahs", {}).items():
                text = verse_data.get("Mustafa Khattab 2018", "")
                self.assertTrue(len(text.strip()) > 0,
                                f"Empty translation at {surah_key}:{verse_key}")

    def test_all_verses_use_consistent_key(self):
        for surah_key, surah_data in self.source.items():
            for verse_key, verse_data in surah_data.get("Ayahs", {}).items():
                self.assertIn("Mustafa Khattab 2018", verse_data,
                              f"Missing key at {surah_key}:{verse_key}")


class TestKhattabConversion(unittest.TestCase):
    """Tests that validate the normalize_text() function."""

    def test_strips_html_i_tags(self):
        result = normalize_text("<i>Alif-Lām-Mīm.</i>", 2, 1)
        self.assertEqual(result, "Alif-Lām-Mīm.")

    def test_decodes_html_entities(self):
        result = normalize_text("You &#761;alone&#762; we worship", 1, 5)
        self.assertIn("\u02f9", result)  # ˹
        self.assertIn("\u02fa", result)  # ˺
        self.assertNotIn("&#", result)

    def test_strips_trailing_whitespace(self):
        result = normalize_text("Some text   ", 1, 1)
        self.assertEqual(result, "Some text")

    def test_preserves_curly_quotes(self):
        result = normalize_text("\u201cBow down\u201d", 1, 1)
        self.assertIn("\u201c", result)
        self.assertIn("\u201d", result)

    def test_preserves_em_dashes(self):
        result = normalize_text("Allah\u2014the Most Compassionate", 1, 1)
        self.assertIn("\u2014", result)

    def test_preserves_angle_brackets(self):
        result = normalize_text("You \u02f9alone\u02fa we worship", 1, 5)
        self.assertIn("\u02f9", result)
        self.assertIn("\u02fa", result)

    def test_preserves_accented_latin(self):
        result = normalize_text("\u1e62\u0101li\u1e25", 1, 1)
        self.assertEqual(result, "\u1e62\u0101li\u1e25")

    def test_fixes_77_48_unmatched_bracket(self):
        raw = 'When it is said to them, "Bow down \u02f9before Allah," they do not bow.'
        result = normalize_text(raw, 77, 48)
        self.assertEqual(result.count("\u02f9"), result.count("\u02fa"))

    def test_no_raw_html_entities_remain(self):
        result = normalize_text("&#761;test&#762; and &#297;", 1, 1)
        self.assertNotIn("&#", result)

    def test_no_html_tags_remain(self):
        result = normalize_text("<i>text</i> <b>bold</b>", 1, 1)
        self.assertNotIn("<", result)
        self.assertNotIn(">", result)


class TestKhattabOutput(unittest.TestCase):
    """Tests that validate the final overlay JSON."""

    @classmethod
    def setUpClass(cls):
        if not os.path.exists(OUTPUT_PATH):
            raise unittest.SkipTest("Output file not found — run fetch_khattab.py first")
        with open(OUTPUT_PATH, "r", encoding="utf-8") as f:
            cls.overlay = json.load(f)

    def test_output_has_6236_entries(self):
        self.assertEqual(len(self.overlay), 6236)

    def test_output_keys_format(self):
        pattern = re.compile(r"^\d+:\d+$")
        for key in self.overlay:
            self.assertTrue(pattern.match(key), f"Bad key format: {key}")

    def test_no_empty_values(self):
        empty = [k for k, v in self.overlay.items() if not v.strip()]
        self.assertEqual(len(empty), 0, f"Empty values: {empty}")

    def test_matched_brackets(self):
        for key, text in self.overlay.items():
            opens = text.count("\u02f9")
            closes = text.count("\u02fa")
            self.assertEqual(opens, closes,
                             f"{key}: {opens} open vs {closes} close brackets")

    def test_spot_check_1_1(self):
        v = self.overlay["1:1"]
        self.assertIn("Allah", v)
        self.assertIn("Most Compassionate", v)
        self.assertIn("Most Merciful", v)

    def test_spot_check_2_1(self):
        v = self.overlay["2:1"]
        self.assertIn("Alif", v)
        self.assertNotIn("<i>", v)
        self.assertNotIn("</i>", v)

    def test_spot_check_1_5(self):
        v = self.overlay["1:5"]
        self.assertIn("\u02f9alone\u02fa", v)
        self.assertNotIn("\u2016", v)  # no double vertical bars

    def test_spot_check_77_48(self):
        v = self.overlay["77:48"]
        opens = v.count("\u02f9")
        closes = v.count("\u02fa")
        self.assertEqual(opens, closes)

    def test_allah_is_primary_divine_name(self):
        """Khattab uses 'Allah' primarily, unlike Itani who uses 'God' exclusively."""
        allah_verses = [k for k, v in self.overlay.items()
                        if re.search(r'\bAllah\b', v)]
        god_verses = [k for k, v in self.overlay.items()
                      if re.search(r'\bGod\b', v)]
        self.assertGreater(len(allah_verses), 1500,
                           "Expected 1500+ verses with 'Allah'")
        self.assertLess(len(god_verses), 50,
                        f"Too many 'God' verses ({len(god_verses)}) — expected <50 (compound uses only)")

    def test_no_html_tags_in_output(self):
        tagged = [k for k, v in self.overlay.items() if '<i>' in v or '</i>' in v]
        self.assertEqual(len(tagged), 0, f"{len(tagged)} verses have HTML tags")

    def test_no_html_entities_in_output(self):
        entities = [k for k, v in self.overlay.items() if '&#' in v]
        self.assertEqual(len(entities), 0, f"{len(entities)} verses have HTML entities")

    def test_no_trailing_whitespace(self):
        trailing = [k for k, v in self.overlay.items() if v != v.strip()]
        self.assertEqual(len(trailing), 0, f"{len(trailing)} verses have trailing whitespace")


if __name__ == "__main__":
    unittest.main()
