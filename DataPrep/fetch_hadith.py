#!/usr/bin/env python3
"""Download hadith text from AhmedBaset/hadith-json and grades from fawazahmed0/hadith-api."""
import json
import os
import time
import urllib.request

BASE_AHMEDBASET = "https://raw.githubusercontent.com/AhmedBaset/hadith-json/main/db/by_book"
BASE_FAWAZ = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions"

# 17 collections from AhmedBaset/hadith-json
AHMEDBASET_BOOKS = {
    "the_9_books": [
        "bukhari", "muslim", "abudawud", "tirmidhi", "nasai",
        "ibnmajah", "malik", "ahmed", "darimi",
    ],
    "forties": [
        "nawawi40", "qudsi40", "shahwaliullah40",
    ],
    "other_books": [
        "aladab_almufrad", "bulugh_almaram", "mishkat_almasabih",
        "riyad_assalihin", "shamail_muhammadiyah",
    ],
}

# 10 graded collections from fawazahmed0 — maps AhmedBaset name → fawazahmed0 slug
GRADE_SLUGS = {
    "bukhari": "bukhari",
    "muslim": "muslim",
    "abudawud": "abudawud",
    "tirmidhi": "tirmidhi",
    "nasai": "nasai",
    "ibnmajah": "ibnmajah",
    "malik": "malik",
    "nawawi40": "nawawi",
    "qudsi40": "qudsi",
    "shahwaliullah40": "dehlawi",
}

OUT_TEXT = "source/hadith-json"
OUT_GRADES = "source/hadith-grades"


def fetch(url, dest):
    if os.path.exists(dest):
        print(f"  skip (exists): {dest}")
        return True
    print(f"  GET {url}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Niya/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(raw)
        # Validate JSON
        json.loads(raw.decode("utf-8"), strict=False)
        size_kb = len(raw) // 1024
        print(f"  saved: {dest} ({size_kb}KB)")
        return True
    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    print("=== Downloading hadith text from AhmedBaset/hadith-json ===")
    for category, books in AHMEDBASET_BOOKS.items():
        for book in books:
            url = f"{BASE_AHMEDBASET}/{category}/{book}.json"
            dest = f"{OUT_TEXT}/{book}.json"
            fetch(url, dest)
            time.sleep(0.3)

    print("\n=== Downloading grades from fawazahmed0/hadith-api ===")
    for ahmedbaset_name, fawaz_slug in GRADE_SLUGS.items():
        url = f"{BASE_FAWAZ}/eng-{fawaz_slug}.min.json"
        dest = f"{OUT_GRADES}/{ahmedbaset_name}.json"
        fetch(url, dest)
        time.sleep(0.5)

    print("\nDone")


if __name__ == "__main__":
    main()
