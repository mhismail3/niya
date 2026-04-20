#!/usr/bin/env python3
"""Fetch Quran translations from alquran.cloud API."""
import json
import os
import re
import time
import urllib.request

_HTML_TAG_RE = re.compile(r"<[a-zA-Z/][^>]*>")
_TRAILING_GARBAGE_RE = re.compile(r"[\s\u3000\ufffd]+$")


def _normalize(text):
    """Strip upstream HTML tag artefacts and trailing whitespace/replacement chars.

    AlQuran.cloud occasionally serves translations with stray <br> tags (seen
    in zh.jian 4:12) and trailing ideographic spaces. Normalise on fetch so
    re-runs do not re-introduce the artefacts.
    """
    text = _HTML_TAG_RE.sub("", text)
    text = _TRAILING_GARBAGE_RE.sub("", text)
    return text

EDITIONS = [
    ("en.sahih",      "en_sahih",      "en", "English",    "Sahih International",        "Saheeh International"),
    ("MANUAL",        "en_clearquran", "en", "English",    "The Clear Quran",            "Dr. Mustafa Khattab"),
    ("en.hilali",     "en_hilali",     "en", "English",    "Al-Hilali & Khan",           "Muhammad Taqi-ud-Din al-Hilali and Muhammad Muhsin Khan"),
    ("fr.hamidullah", "fr_hamidullah", "fr", "French",     "Muhammad Hamidullah",        "Muhammad Hamidullah"),
    # es.abboud was removed from AlQuran.cloud (API now silently returns
    # Arabic). The bundled Spanish predates that change; mark PRESERVED so
    # re-runs neither re-fetch nor overwrite it.
    ("PRESERVED",     "es_abboud",     "es", "Spanish",    "Abboud & Castellanos",       "Ahmad Abboud & Rafael Castellanos"),
    ("it.piccardo",   "it_piccardo",   "it", "Italian",    "Hamza Roberto Piccardo",     "Hamza Roberto Piccardo"),
    ("tr.diyanet",    "tr_diyanet",    "tr", "Turkish",    "Diyanet Isleri",             "Diyanet Isleri Baskanligi"),
    ("ur.maududi",    "ur_maududi",    "ur", "Urdu",       "Syed Abul Aala Maududi",    "Syed Abul Aala Maududi"),
    ("ps.abdulwali",  "ps_abdulwali",  "ps", "Pashto",     "Abdulwali Khan",             "Mufti Abdul Wali Khan al-Darwazi"),
    ("QURANENC",      "ps_rwwad",      "ps", "Pashto",     "Rowwad Translation Center",  "Rowwad Translation Center / KFGQPC"),
    ("fa.makarem",    "fa_makarem",    "fa", "Persian",    "Makarem Shirazi",            "Naser Makarem Shirazi"),
    ("fa.fooladvand", "fa_fooladvand", "fa", "Persian",    "Fooladvand",                 "Mohammad Mahdi Fooladvand"),
    ("QURANENC",      "el_rwwad",      "el", "Greek",      "Rowwad Translation Center",  "Rowwad Translation Center / KFGQPC"),
    ("id.indonesian", "id_indonesian", "id", "Indonesian", "Kemenag",                    "Indonesian Ministry of Religious Affairs"),
    ("bn.bengali",    "bn_bengali",    "bn", "Bengali",    "Muhiuddin Khan",             "Muhiuddin Khan"),
    ("de.bubenheim",  "de_bubenheim",  "de", "German",     "Bubenheim & Elyas",          "A. S. F. Bubenheim and N. Elyas"),
    ("ru.kuliev",     "ru_kuliev",     "ru", "Russian",    "Elmir Kuliev",               "Elmir Kuliev"),
    ("ms.basmeih",    "ms_basmeih",    "ms", "Malay",      "Abdullah Basmeih",           "Abdullah Muhammad Basmeih"),
    ("zh.jian",       "zh_jian",       "zh", "Chinese",    "Ma Jian",                    "Ma Jian"),
    ("my.ghazi",      "my_ghazi",      "my", "Burmese",    "Ghazi Muhammed Hashim",      "Ghazi Muhammed Hashim"),
]

# Sentinel api_id values mean "this edition is not fetched by this script".
# When seen, fetch_translations.py just registers the edition in the index
# (provided the file already exists on disk). The value is either the name
# of the producer script, or None for editions with no producer (preserved
# from a prior fetch).
EXTERNAL_SENTINELS = {
    "MANUAL":    "fetch_khattab.py",
    "QURANENC":  "fetch_quranenc.py",
    "PRESERVED": None,
}

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output", "translations")
os.makedirs(OUTPUT_DIR, exist_ok=True)

index = []

for api_id, output_id, lang, lang_name, name, author in EDITIONS:
    out_path = os.path.join(OUTPUT_DIR, f"translation_{output_id}.json")

    if api_id in EXTERNAL_SENTINELS:
        producer = EXTERNAL_SENTINELS[api_id]
        if not os.path.exists(out_path):
            hint = f"run {producer}" if producer else "restore from git or rebundle manually"
            print(f"  WARNING: {output_id} is {api_id} — {hint}")
        else:
            print(f"  {output_id}: {api_id} (already built)")
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
                overlay[key] = _normalize(a["text"])

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
