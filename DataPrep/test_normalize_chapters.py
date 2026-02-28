#!/usr/bin/env python3
"""Unit tests for normalize_chapters in build_hadith.py."""
import unittest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_hadith import normalize_chapters


class TestNormalizeChapters(unittest.TestCase):

    def test_null_chapter_id_gets_sequential_id(self):
        chapters = [
            {"id": 35, "english": "Ch 35", "arabic": ""},
            {"id": None, "english": "Agriculture", "arabic": "كتاب المزارعة"},
            {"id": 37, "english": "Ch 37", "arabic": ""},
        ]
        hadiths = []
        norm_ch, _ = normalize_chapters(chapters, hadiths)
        ids = [c["id"] for c in norm_ch]
        self.assertEqual(ids, [1, 2, 3])

    def test_orphan_hadiths_assigned_to_null_chapter(self):
        chapters = [
            {"id": 1, "english": "Ch 1", "arabic": ""},
            {"id": None, "english": "Agriculture", "arabic": "كتاب المزارعة"},
        ]
        hadiths = [
            {"idInBook": 100, "chapterId": None, "arabic": "test"},
            {"idInBook": 101, "chapterId": 1, "arabic": "test2"},
        ]
        _, norm_h = normalize_chapters(chapters, hadiths)
        # Null chapter becomes id=2, orphan hadith gets chapterId=2
        self.assertEqual(norm_h[0]["chapterId"], 2)
        # Hadith with chapterId=1 maps to new id=1
        self.assertEqual(norm_h[1]["chapterId"], 1)

    def test_subsequent_chapter_ids_shifted(self):
        chapters = [
            {"id": 1, "english": "A", "arabic": ""},
            {"id": None, "english": "B", "arabic": ""},
            {"id": 3, "english": "C", "arabic": ""},
        ]
        norm_ch, _ = normalize_chapters(chapters, [])
        self.assertEqual([c["id"] for c in norm_ch], [1, 2, 3])

    def test_subsequent_hadith_chapter_ids_remapped(self):
        chapters = [
            {"id": 10, "english": "A", "arabic": ""},
            {"id": 20, "english": "B", "arabic": ""},
        ]
        hadiths = [
            {"idInBook": 1, "chapterId": 10, "arabic": ""},
            {"idInBook": 2, "chapterId": 20, "arabic": ""},
        ]
        _, norm_h = normalize_chapters(chapters, hadiths)
        self.assertEqual(norm_h[0]["chapterId"], 1)
        self.assertEqual(norm_h[1]["chapterId"], 2)

    def test_no_null_ids_all_normal(self):
        chapters = [
            {"id": 1, "english": "A", "arabic": ""},
            {"id": 2, "english": "B", "arabic": ""},
            {"id": 3, "english": "C", "arabic": ""},
        ]
        hadiths = [
            {"idInBook": 1, "chapterId": 2, "arabic": ""},
        ]
        norm_ch, norm_h = normalize_chapters(chapters, hadiths)
        self.assertEqual([c["id"] for c in norm_ch], [1, 2, 3])
        self.assertEqual(norm_h[0]["chapterId"], 2)

    def test_multiple_null_chapters(self):
        chapters = [
            {"id": None, "english": "A", "arabic": ""},
            {"id": 5, "english": "B", "arabic": ""},
            {"id": None, "english": "C", "arabic": ""},
        ]
        hadiths = [
            {"idInBook": 1, "chapterId": None, "arabic": ""},
            {"idInBook": 2, "chapterId": 5, "arabic": ""},
        ]
        norm_ch, norm_h = normalize_chapters(chapters, hadiths)
        self.assertEqual([c["id"] for c in norm_ch], [1, 2, 3])
        self.assertIsNotNone(norm_h[0]["chapterId"])
        self.assertIn(norm_h[0]["chapterId"], [1, 3])  # assigned to a null-origin chapter
        self.assertEqual(norm_h[1]["chapterId"], 2)

    def test_empty_title_preserved(self):
        chapters = [
            {"id": 1, "english": "", "arabic": "مسند"},
        ]
        norm_ch, _ = normalize_chapters(chapters, [])
        self.assertEqual(norm_ch[0]["english"], "")
        self.assertEqual(norm_ch[0]["arabic"], "مسند")

    def test_chapter_metadata_preserved(self):
        chapters = [
            {"id": 5, "english": "Book of Faith", "arabic": "كتاب الإيمان", "bookId": 3},
        ]
        norm_ch, _ = normalize_chapters(chapters, [])
        self.assertEqual(norm_ch[0]["english"], "Book of Faith")
        self.assertEqual(norm_ch[0]["arabic"], "كتاب الإيمان")
        self.assertEqual(norm_ch[0]["bookId"], 3)


if __name__ == "__main__":
    unittest.main()
