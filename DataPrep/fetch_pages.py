#!/usr/bin/env python3
"""Fetch mushaf page numbers from alquran.cloud API."""
import json
import time
import urllib.request

def fetch_surah_pages(surah_num):
    url = f"https://api.alquran.cloud/v1/surah/{surah_num}"
    with urllib.request.urlopen(url, timeout=10) as resp:
        raw = resp.read().decode('utf-8')
    # Use strict=False to handle embedded control chars in Arabic text
    d = json.loads(raw, strict=False)
    results = []
    for a in d['data']['ayahs']:
        results.append(json.dumps({'surah': surah_num, 'ayah': a['numberInSurah'], 'page': a['page']}))
    return results

with open('page_numbers.jsonl', 'w') as out:
    for surah in range(1, 115):
        try:
            lines = fetch_surah_pages(surah)
            for line in lines:
                out.write(line + '\n')
            out.flush()
            print(f"Surah {surah}: {len(lines)} ayahs")
        except Exception as e:
            print(f"Error surah {surah}: {e}")
        time.sleep(0.3)

print("Done")
