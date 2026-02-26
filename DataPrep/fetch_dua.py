#!/usr/bin/env python3
"""
fetch_dua.py — Copy dua source data from cloned repos.

Expects repos already cloned at /tmp/:
  - /tmp/hisn-muslim-json/husn_en.json
  - /tmp/dua-dhikr/data/dua-dhikr/*/en.json
"""

import shutil
import os
import glob

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(SCRIPT_DIR, "source", "dua")
FITRAHIVE_DIR = os.path.join(OUT_DIR, "fitrahive")

os.makedirs(FITRAHIVE_DIR, exist_ok=True)

# Primary: Hisn al-Muslim
src = "/tmp/hisn-muslim-json/husn_en.json"
dst = os.path.join(OUT_DIR, "husn_en.json")
shutil.copy2(src, dst)
print(f"Copied {src} -> {dst}")

# Supplementary: fitrahive dua-dhikr
for en_path in sorted(glob.glob("/tmp/dua-dhikr/data/dua-dhikr/*/en.json")):
    cat_name = os.path.basename(os.path.dirname(en_path))
    dst = os.path.join(FITRAHIVE_DIR, f"{cat_name}.json")
    shutil.copy2(en_path, dst)
    print(f"Copied {en_path} -> {dst}")

print("Done.")
