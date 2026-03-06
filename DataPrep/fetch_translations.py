#!/usr/bin/env python3
"""Fetch Quran translations from alquran.cloud API."""
import json
import os
import time
import urllib.request

EDITIONS = [
    ("en.sahih",      "en_sahih",      "en", "English",    "Sahih International",        "Saheeh International"),
    ("MANUAL",        "en_clearquran", "en", "English",    "The Clear Quran",            "Dr. Mustafa Khattab"),
    ("en.hilali",     "en_hilali",     "en", "English",    "Al-Hilali & Khan",           "Muhammad Taqi-ud-Din al-Hilali and Muhammad Muhsin Khan"),
    ("fr.hamidullah", "fr_hamidullah", "fr", "French",     "Muhammad Hamidullah",        "Muhammad Hamidullah"),
    ("es.abboud",     "es_abboud",     "es", "Spanish",    "Abboud & Castellanos",       "Ahmad Abboud & Rafael Castellanos"),
    ("tr.diyanet",    "tr_diyanet",    "tr", "Turkish",    "Diyanet Isleri",             "Diyanet Isleri Baskanligi"),
    ("ur.maududi",    "ur_maududi",    "ur", "Urdu",       "Syed Abul Aala Maududi",    "Syed Abul Aala Maududi"),
    ("id.indonesian", "id_indonesian", "id", "Indonesian", "Kemenag",                    "Indonesian Ministry of Religious Affairs"),
    ("bn.bengali",    "bn_bengali",    "bn", "Bengali",    "Muhiuddin Khan",             "Muhiuddin Khan"),
    ("de.bubenheim",  "de_bubenheim",  "de", "German",     "Bubenheim & Elyas",          "A. S. F. Bubenheim and N. Elyas"),
    ("ru.kuliev",     "ru_kuliev",     "ru", "Russian",    "Elmir Kuliev",               "Elmir Kuliev"),
    ("ms.basmeih",    "ms_basmeih",    "ms", "Malay",      "Abdullah Basmeih",           "Abdullah Muhammad Basmeih"),
    ("zh.jian",       "zh_jian",       "zh", "Chinese",    "Ma Jian",                    "Ma Jian"),
    ("my.ghazi",      "my_ghazi",      "my", "Burmese",    "Ghazi Muhammed Hashim",      "Ghazi Muhammed Hashim"),
]

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output", "translations")
os.makedirs(OUTPUT_DIR, exist_ok=True)

index = []

for api_id, output_id, lang, lang_name, name, author in EDITIONS:
    out_path = os.path.join(OUTPUT_DIR, f"translation_{output_id}.json")

    if api_id == "MANUAL":
        if not os.path.exists(out_path):
            print(f"  WARNING: {output_id} is MANUAL — run fetch_khattab.py first")
        else:
            print(f"  {output_id}: MANUAL (already built)")
        index.append({
            "id": output_id,
            "language": lang,
            "languageName": lang_name,
            "name": name,
            "author": author,
            "filename": f"translation_{output_id}.json",
        })
        continue

    if os.path.exists(out_path):
        print(f"  Skipping {output_id} (already exists)")
        index.append({
            "id": output_id,
            "language": lang,
            "languageName": lang_name,
            "name": name,
            "author": author,
            "filename": f"translation_{output_id}.json",
        })
        continue

    url = f"https://api.alquran.cloud/v1/quran/{api_id}"
    print(f"Fetching {output_id} from {api_id}...")
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
        data = json.loads(raw, strict=False)

        overlay = {}
        for ayah in data["data"]["surahs"]:
            surah_num = ayah["number"]
            for a in ayah["ayahs"]:
                key = f"{surah_num}:{a['numberInSurah']}"
                overlay[key] = a["text"]

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(overlay, f, ensure_ascii=False)

        print(f"  {output_id}: {len(overlay)} verses")
        index.append({
            "id": output_id,
            "language": lang,
            "languageName": lang_name,
            "name": name,
            "author": author,
            "filename": f"translation_{output_id}.json",
        })
    except Exception as e:
        print(f"  ERROR {output_id}: {e}")

    time.sleep(0.5)

index_path = os.path.join(OUTPUT_DIR, "translations_index.json")
with open(index_path, "w", encoding="utf-8") as f:
    json.dump(index, f, ensure_ascii=False, indent=2)

print(f"\nDone. {len(index)} translations fetched. Index at {index_path}")
