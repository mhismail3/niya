#!/usr/bin/env python3
"""
fetch_noreen_audio.py — Download Sheikh Noreen Mohammad Siddiq's recitation.

Downloads all 114 surah MP3s from QuranicAudio.com CDN.
Saves to DataPrep/noreen_audio/ (gitignored). Resume-friendly.
"""

import os
import urllib.request

BASE_URL = "https://download.quranicaudio.com/quran/noreen_siddiq"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "noreen_audio")


def download_all():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for surah_id in range(1, 115):
        filename = f"{surah_id:03d}.mp3"
        local_path = os.path.join(OUTPUT_DIR, filename)

        if os.path.exists(local_path) and os.path.getsize(local_path) > 0:
            print(f"[{surah_id:3d}/114] Already downloaded: {filename}")
            continue

        url = f"{BASE_URL}/{filename}"
        print(f"[{surah_id:3d}/114] Downloading {url} ...")
        try:
            urllib.request.urlretrieve(url, local_path)
            size_mb = os.path.getsize(local_path) / (1024 * 1024)
            print(f"         Saved {size_mb:.1f} MB")
        except Exception as e:
            print(f"         ERROR: {e}")
            if os.path.exists(local_path):
                os.remove(local_path)

    # Validate all 114 present and non-zero
    missing = []
    for surah_id in range(1, 115):
        path = os.path.join(OUTPUT_DIR, f"{surah_id:03d}.mp3")
        if not os.path.exists(path) or os.path.getsize(path) == 0:
            missing.append(surah_id)

    if missing:
        print(f"\nMISSING or empty: {missing}")
    else:
        print(f"\nAll 114 surah files downloaded successfully.")


if __name__ == "__main__":
    download_all()
