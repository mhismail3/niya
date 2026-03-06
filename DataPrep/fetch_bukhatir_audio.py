#!/usr/bin/env python3
"""
fetch_bukhatir_audio.py — Download all 114 surah MP3s for Salah Bukhatir.

Source: QuranicAudio.com (Hafs, murattal)
URL pattern: https://download.quranicaudio.com/quran/salaah_bukhaatir/{surahId:03d}.mp3

Output: DataPrep/bukhatir_audio/{001-114}.mp3
"""

import os
import sys
import time
import urllib.request
import urllib.error

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "bukhatir_audio")
CDN_BASE = "https://download.quranicaudio.com/quran/salaah_bukhaatir"
RATE_LIMIT = 0.5


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    skipped = 0
    downloaded = 0
    failed = []

    for surah_id in range(1, 115):
        filename = f"{surah_id:03d}.mp3"
        output_path = os.path.join(OUTPUT_DIR, filename)

        if os.path.exists(output_path):
            size = os.path.getsize(output_path)
            if size > 0:
                print(f"  [{surah_id:3d}/114] SKIP (exists, {size / 1024:.0f} KB)")
                skipped += 1
                continue

        url = f"{CDN_BASE}/{filename}"
        print(f"  [{surah_id:3d}/114] Downloading {url}...")

        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Niya/1.0"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = resp.read()
            with open(output_path, "wb") as f:
                f.write(data)
            print(f"           OK ({len(data) / 1024:.0f} KB)")
            downloaded += 1
        except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
            print(f"           FAIL: {e}")
            failed.append(surah_id)

        time.sleep(RATE_LIMIT)

    print(f"\nDone: {downloaded} downloaded, {skipped} skipped, {len(failed)} failed")
    if failed:
        print(f"Failed surahs: {failed}")
        sys.exit(1)


if __name__ == "__main__":
    main()
