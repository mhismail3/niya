#!/usr/bin/env python3
"""Fetch Darimi English translations from hadithunlocked.com and merge into hadith_darimi.json."""

import csv
import io
import json
import os
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
TSV_URL = "https://hadithunlocked.com/darimi?download&tsv"
TSV_PATH = os.path.join(SCRIPT_DIR, "source", "hadith-supplement", "darimi_unlocked.tsv")
JSON_PATH = os.path.join(PROJECT_DIR, "Niya", "Resources", "Data", "hadith_darimi.json")


def download_tsv():
    os.makedirs(os.path.dirname(TSV_PATH), exist_ok=True)
    if os.path.exists(TSV_PATH):
        print(f"Using cached TSV: {TSV_PATH}")
        return
    print(f"Downloading TSV from {TSV_URL} ...")
    req = urllib.request.Request(TSV_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
    with open(TSV_PATH, "wb") as f:
        f.write(data)
    print(f"Saved {len(data):,} bytes to {TSV_PATH}")


def parse_tsv():
    """Parse TSV and return dict mapping hadith number (int) to English body text."""
    translations = {}
    with open(TSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            ref = row.get("ref", "")
            # Format: "darimi:N"
            if not ref.startswith("darimi:"):
                continue
            try:
                hid = int(ref.split(":")[1])
            except (IndexError, ValueError):
                continue
            body = row.get("body_en", "").strip()
            body = body.removeprefix("[Machine]").strip()
            if body:
                translations[hid] = body
    return translations


CHAPTER_TITLES = {
    1: "Book of Purification",
    2: "Book of Prayer",
    3: "Book of Zakah",
    4: "Book of Fasting",
    5: "Book of Rites",
    6: "Book of Sacrifices",
    7: "Book of Hunting",
    8: "Book of Food",
    9: "Book of Drinks",
    10: "Book of Visions",
    11: "Book of Marriage",
    12: "Book of Divorce",
    13: "Book of Penalties",
    14: "Book of Vows and Oaths",
    15: "Book of Blood Money",
    16: "Book of Jihad",
    17: "Book of Expeditions",
    18: "Book of Transactions",
    19: "Book of Seeking Permission",
    20: "Book of Heart-Softening",
    21: "Book of Inheritance",
    22: "Book of Wills",
    23: "Book of Virtues of the Quran",
    24: "Sunan al-Darimi",
}


def merge(translations):
    with open(JSON_PATH, encoding="utf-8") as f:
        data = json.load(f)

    for ch in data["chapters"]:
        title = CHAPTER_TITLES.get(ch["id"])
        if title:
            ch["title"] = title

    matched = 0
    for h in data["hadiths"]:
        hid = h["id"]
        if hid in translations:
            h["text"] = translations[hid]
            matched += 1

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=None, separators=(",", ":"))

    total = len(data["hadiths"])
    titled = sum(1 for ch in data["chapters"] if ch.get("title"))
    print(f"Chapter titles: {titled}/{len(data['chapters'])}")
    print(f"Matched {matched}/{total} hadiths ({matched*100/total:.1f}%)")
    missing = [h["id"] for h in data["hadiths"] if not h.get("text")]
    if missing:
        print(f"Missing translations for {len(missing)} hadiths: {missing[:10]}...")
    else:
        print("All hadiths have English text.")


if __name__ == "__main__":
    download_tsv()
    translations = parse_tsv()
    print(f"Parsed {len(translations)} translations from TSV")
    merge(translations)
