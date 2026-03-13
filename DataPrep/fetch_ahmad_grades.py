#!/usr/bin/env python3
"""Scrape Darussalam grades for Musnad Ahmad hadiths from sunnah.com."""
import json
import os
import re
import time
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "source", "hadith-grades", "ahmed.json")
CACHE_DIR = os.path.join(SCRIPT_DIR, "cache", "ahmad-pages")
TOTAL_HADITHS = 1374
DELAY = 0.5


def fetch_page(hadith_num):
    """Fetch a sunnah.com hadith page, using cache if available."""
    cache_path = os.path.join(CACHE_DIR, f"{hadith_num}.html")
    if os.path.exists(cache_path):
        with open(cache_path, encoding="utf-8") as f:
            return f.read()

    url = f"https://sunnah.com/ahmad:{hadith_num}"
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Niya/1.0",
        "Accept": "text/html",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        html = resp.read().decode("utf-8")

    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as f:
        f.write(html)
    return html


def extract_grade(html):
    """Extract grade text from the HTML page.

    sunnah.com format:
      <td class=english_grade ...>&nbsp;<b>Sahih (Darussalam)</b> (Darussalam)</td>
    """
    # Match the grade bold text inside english_grade cell after the "Grade:" cell
    m = re.search(
        r'<b>Grade</b>.*?<td[^>]*class=english_grade[^>]*>\s*(?:&nbsp;)?\s*<b>(.*?)</b>',
        html, re.DOTALL | re.IGNORECASE,
    )
    if m:
        grade = m.group(1).strip()
        grade = re.sub(r'<[^>]+>', '', grade).strip()
        if grade:
            return grade

    return None


def main():
    os.chdir(SCRIPT_DIR)

    print(f"Fetching Darussalam grades for Musnad Ahmad ({TOTAL_HADITHS} hadiths)")
    print(f"Cache: {CACHE_DIR}")
    print(f"Output: {OUTPUT_FILE}\n")

    hadiths = []
    missing = []

    for num in range(1, TOTAL_HADITHS + 1):
        cached = os.path.exists(os.path.join(CACHE_DIR, f"{num}.html"))
        try:
            html = fetch_page(num)
            grade = extract_grade(html)
        except Exception as e:
            print(f"  [{num}/{TOTAL_HADITHS}] ERROR fetching: {e}")
            missing.append(num)
            hadiths.append({"hadithnumber": num, "grades": []})
            continue

        if grade:
            hadiths.append({
                "hadithnumber": num,
                "grades": [{"grade": grade}],
            })
            status = "cached" if cached else "fetched"
            if num % 100 == 0 or num == 1:
                print(f"  [{num}/{TOTAL_HADITHS}] {status}: {grade}")
        else:
            missing.append(num)
            hadiths.append({"hadithnumber": num, "grades": []})
            print(f"  [{num}/{TOTAL_HADITHS}] WARNING: no grade found")

        if not cached:
            time.sleep(DELAY)

    # Write output
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump({"hadiths": hadiths}, f, ensure_ascii=False)

    graded = sum(1 for h in hadiths if h["grades"])
    print(f"\nDone: {graded}/{TOTAL_HADITHS} graded")
    if missing:
        print(f"Missing grades for: {missing[:20]}{'...' if len(missing) > 20 else ''}")


if __name__ == "__main__":
    main()
