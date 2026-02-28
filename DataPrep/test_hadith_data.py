#!/usr/bin/env python3
"""Post-rebuild data integrity tests for all hadith output files."""
import json
import os
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESOURCES_DIR = os.path.join(SCRIPT_DIR, "..", "Niya", "Resources", "Data")

ENABLED_COLLECTIONS = [
    "bukhari", "muslim", "abudawud", "tirmidhi",
    "nasai", "ibnmajah", "malik", "ahmed", "darimi",
    "nawawi", "qudsi", "dehlawi", "aladab", "bulugh",
    "mishkat", "riyad", "shamail",
]


def load_collection(coll_id):
    path = os.path.join(RESOURCES_DIR, f"hadith_{coll_id}.json")
    with open(path, encoding="utf-8") as f:
        return json.loads(f.read(), strict=False)


class TestHadithDataIntegrity(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.data = {}
        for cid in ENABLED_COLLECTIONS:
            path = os.path.join(RESOURCES_DIR, f"hadith_{cid}.json")
            if os.path.exists(path):
                cls.data[cid] = load_collection(cid)

    def test_nasai_no_null_chapter_ids(self):
        for ch in self.data["nasai"]["chapters"]:
            self.assertIsInstance(ch["id"], int, f"Chapter has non-int id: {ch}")

    def test_nasai_no_null_chapter_ids_in_hadiths(self):
        for h in self.data["nasai"]["hadiths"]:
            self.assertIsInstance(h["chapterId"], int,
                f"Hadith #{h['id']} has non-int chapterId: {h['chapterId']}")

    def test_nasai_chapter_count(self):
        self.assertEqual(len(self.data["nasai"]["chapters"]), 52)

    def test_nasai_hadith_count(self):
        self.assertEqual(len(self.data["nasai"]["hadiths"]), 5768)

    def test_nasai_agriculture_chapter_exists(self):
        agriculture = [c for c in self.data["nasai"]["chapters"]
                      if "Agriculture" in c.get("title", "")]
        self.assertEqual(len(agriculture), 1, "Agriculture chapter not found")
        ch = agriculture[0]
        self.assertEqual(len(ch["hadithRange"]), 2)
        self.assertEqual(ch["hadithRange"][1] - ch["hadithRange"][0] + 1, 83)

    def test_ahmed_empty_title_chapter_has_arabic(self):
        chapters = self.data["ahmed"]["chapters"]
        empty_title = [c for c in chapters if c["title"] == ""]
        self.assertGreater(len(empty_title), 0,
            "Ahmed should have at least one chapter with empty English title")
        for ch in empty_title:
            self.assertTrue(len(ch["titleArabic"]) > 0,
                f"Ahmed chapter {ch['id']} with empty title should have Arabic title")

    def test_all_collections_decodable(self):
        for cid in ENABLED_COLLECTIONS:
            if cid not in self.data:
                continue
            data = self.data[cid]
            for ch in data["chapters"]:
                self.assertIsInstance(ch["id"], int, f"{cid} chapter id not int")
                self.assertIsInstance(ch["title"], str, f"{cid} chapter title not str")
                self.assertIsInstance(ch["titleArabic"], str)
            for h in data["hadiths"]:
                self.assertIsInstance(h["id"], int, f"{cid} hadith id not int")
                self.assertIsInstance(h["chapterId"], int, f"{cid} hadith chapterId not int")

    def test_every_hadith_has_arabic(self):
        for cid, data in self.data.items():
            empty = sum(1 for h in data["hadiths"] if not h["arabic"])
            total = len(data["hadiths"])
            # Malik has ~6% empty arabic in source data
            self.assertLess(empty / max(total, 1), 0.10,
                f"{cid}: {empty}/{total} hadiths have empty arabic")

    def test_chapter_hadith_ranges_valid(self):
        for cid, data in self.data.items():
            for ch in data["chapters"]:
                r = ch["hadithRange"]
                self.assertIn(len(r), [0, 2],
                    f"{cid} chapter {ch['id']} hadithRange length {len(r)}")
                if len(r) == 2:
                    self.assertLessEqual(r[0], r[1],
                        f"{cid} chapter {ch['id']} range [{r[0]}, {r[1]}] invalid")

    def test_all_hadith_chapter_ids_exist(self):
        for cid, data in self.data.items():
            chapter_ids = {ch["id"] for ch in data["chapters"]}
            for h in data["hadiths"]:
                self.assertIn(h["chapterId"], chapter_ids,
                    f"{cid} hadith #{h['id']} chapterId {h['chapterId']} not in chapters")


if __name__ == "__main__":
    unittest.main()
