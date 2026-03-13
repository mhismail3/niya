#!/usr/bin/env python3
"""Scrape missing hadiths and grades from sunnah.com for Mishkat and Shamail.

Mishkat al-Masabih: our source (AhmedBaset) has 4,428; sunnah.com has 5,978.
  - Scrape hadiths 1-5978: grades for ALL, text for 4429-5978
Shamail Muhammadiyah: our source has 402; sunnah.com has 417.
  - Scrape hadiths 1-417: grades for ALL, text for 403-417
"""
import json
import os
import re
import time
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(SCRIPT_DIR, "cache", "sunnah-pages")

COLLECTIONS = {
    "mishkat": {
        "slug": "mishkat",
        "max_hadith": 5978,
        "existing_max": 4428,
        "grade_file": "mishkat_grades.json",
        "supplement_file": "mishkat_supplement.json",
    },
    "shamail": {
        "slug": "shamail",
        "max_hadith": 417,
        "existing_max": 402,
        "grade_file": "shamail_grades.json",
        "supplement_file": "shamail_supplement.json",
    },
}

DELAY = 0.5


def fetch_page(slug, hadith_num):
    """Fetch a sunnah.com hadith page, using cache if available."""
    cache_path = os.path.join(CACHE_DIR, slug, f"{hadith_num}.html")
    if os.path.exists(cache_path):
        with open(cache_path, encoding="utf-8") as f:
            return f.read(), True

    url = f"https://sunnah.com/{slug}:{hadith_num}"
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Niya/1.0",
        "Accept": "text/html",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        html = resp.read().decode("utf-8")

    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as f:
        f.write(html)
    return html, False


def extract_grade(html):
    """Extract grade from sunnah.com HTML.

    Checks English grade first, falls back to Arabic grade.
    Returns (english_grade, arabic_grade, grader) tuple.
    """
    eng_grade = ""
    arb_grade = ""
    grader = ""

    for line in html.split('\n'):
        if 'gradetable' not in line:
            continue

        # English grade (after Grade: label)
        m = re.search(
            r'<b>Grade</b>.*?<td[^>]*class=english_grade[^>]*>\s*(?:&nbsp;)?\s*<b>(.*?)</b>',
            line, re.DOTALL,
        )
        if m:
            eng_grade = re.sub(r'<[^>]+>', '', m.group(1)).strip()

        # Arabic grade (first arabic_grade cell)
        m2 = re.search(
            r'class="?arabic_grade[^>]*>&nbsp;\s*<b>(.*?)</b>',
            line, re.DOTALL,
        )
        if m2:
            arb_grade = re.sub(r'<[^>]+>', '', m2.group(1)).strip()

        # Grader name (in parentheses after Arabic grade)
        m3 = re.search(
            r'class="?arabic_grade[^>]*>&nbsp;\s*<b>[^<]*</b>&nbsp;&nbsp;\s*\(([^)]+)\)',
            line, re.DOTALL,
        )
        if m3:
            grader = m3.group(1).strip()

        break

    return eng_grade, arb_grade, grader


def extract_hadith_text(html):
    """Extract Arabic text, English text, narrator, chapter info from HTML."""
    result = {}

    # English text
    m = re.search(r'class="english_hadith_full"[^>]*>(.*?)</div>', html, re.DOTALL)
    if m:
        text = re.sub(r'<[^>]+>', '', m.group(1)).strip()
        result["english"] = text

    # Arabic text
    m = re.search(r'class="arabic_hadith_full"[^>]*>(.*?)</div>', html, re.DOTALL)
    if m:
        text = re.sub(r'<[^>]+>', '', m.group(1)).strip()
        result["arabic"] = text

    # Narrator (often at start of English text in <b> tags)
    m = re.search(r'class="english_hadith_full"[^>]*>\s*<b>(.*?)</b>', html, re.DOTALL)
    if m:
        narrator = re.sub(r'<[^>]+>', '', m.group(1)).strip()
        if narrator and not narrator.startswith("Chapter"):
            result["narrator"] = narrator

    # In-book reference for chapter/book number
    m = re.search(r'In-book reference.*?Book\s+(\d+).*?Hadith\s+(\d+)', html, re.DOTALL)
    if m:
        result["bookNum"] = int(m.group(1))
        result["inBookHadith"] = int(m.group(2))

    return result


def normalize_arabic_grade_to_english(arb):
    """Convert common Arabic grade terms to English equivalents."""
    arb = arb.strip()
    mapping = {
        "صَحِيح": "Sahih",
        "صحيح": "Sahih",
        "حسن": "Hasan",
        "ضعيف": "Da'if",
        "ضَعِيف": "Da'if",
        "موضوع": "Mawdu'",
        "مُتَّفَقٌ عَلَيْهِ": "Agreed upon",
        "مُتَّفق عَلَيْهِ": "Agreed upon",
        "لم تتمّ دراسته": "Not studied",
    }
    for arb_term, eng_term in mapping.items():
        if arb_term in arb:
            return eng_term
    return arb


def scrape_collection(name, config):
    """Scrape a collection for grades and missing hadiths."""
    slug = config["slug"]
    max_hadith = config["max_hadith"]
    existing_max = config["existing_max"]

    print(f"\n{'='*60}")
    print(f"Scraping {name}: hadiths 1-{max_hadith}")
    print(f"  Existing data: 1-{existing_max}")
    print(f"  New hadiths to fetch: {existing_max+1}-{max_hadith}")
    print(f"{'='*60}\n")

    grades = []  # Grade data for ALL hadiths
    supplements = []  # Full text for NEW hadiths only
    missing = []

    for num in range(1, max_hadith + 1):
        try:
            html, cached = fetch_page(slug, num)
        except Exception as e:
            print(f"  [{num}/{max_hadith}] ERROR: {e}")
            missing.append(num)
            grades.append({"hadithnumber": num, "grades": []})
            continue

        eng_grade, arb_grade, grader = extract_grade(html)

        # Build grade entry
        grade_str = eng_grade or normalize_arabic_grade_to_english(arb_grade)
        if grade_str:
            grades.append({
                "hadithnumber": num,
                "grades": [{"grade": grade_str}],
            })
        else:
            grades.append({"hadithnumber": num, "grades": []})

        # For new hadiths beyond our existing data, extract full text
        if num > existing_max:
            text_data = extract_hadith_text(html)
            if text_data.get("arabic") or text_data.get("english"):
                supplements.append({
                    "hadithNumber": num,
                    "arabic": text_data.get("arabic", ""),
                    "english": text_data.get("english", ""),
                    "narrator": text_data.get("narrator", ""),
                    "bookNum": text_data.get("bookNum"),
                    "grade": grade_str,
                })

        # Progress logging
        status = "cached" if cached else "fetched"
        if num % 500 == 0 or num == 1 or num == max_hadith:
            g = grade_str or "no grade"
            print(f"  [{num}/{max_hadith}] {status}: {g}")

        if not cached:
            time.sleep(DELAY)

    # Write grade file
    grade_dir = os.path.join(SCRIPT_DIR, "source", "hadith-grades")
    os.makedirs(grade_dir, exist_ok=True)
    grade_path = os.path.join(grade_dir, config["grade_file"])
    with open(grade_path, "w", encoding="utf-8") as f:
        json.dump({"hadiths": grades}, f, ensure_ascii=False)

    graded = sum(1 for g in grades if g["grades"])
    print(f"\nGrades: {graded}/{max_hadith} graded -> {grade_path}")

    # Write supplement file (new hadiths)
    if supplements:
        supp_dir = os.path.join(SCRIPT_DIR, "source", "hadith-supplement")
        os.makedirs(supp_dir, exist_ok=True)
        supp_path = os.path.join(supp_dir, config["supplement_file"])
        with open(supp_path, "w", encoding="utf-8") as f:
            json.dump(supplements, f, ensure_ascii=False)
        print(f"Supplements: {len(supplements)} new hadiths -> {supp_path}")

    if missing:
        print(f"Missing/errors: {missing[:20]}{'...' if len(missing) > 20 else ''}")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("collections", nargs="*", default=list(COLLECTIONS.keys()),
                        help="Collections to scrape (default: all)")
    args = parser.parse_args()

    for name in args.collections:
        if name not in COLLECTIONS:
            print(f"Unknown collection: {name}")
            continue
        scrape_collection(name, COLLECTIONS[name])

    print("\nDone!")


if __name__ == "__main__":
    main()
