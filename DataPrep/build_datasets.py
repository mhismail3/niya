#!/usr/bin/env python3
"""Build surahs.json, verses_hafs.json, verses_indopak.json from downloaded data."""
import json

page_map = {}
with open('page_numbers.jsonl') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        page_map[(d['surah'], d['ayah'])] = d['page']

print(f"Page map: {len(page_map)} entries")

with open('surahs-index.json') as f:
    surah_index = json.load(f)

with open('quran_indopak.json') as f:
    indopak = json.load(f)

# surahs.json
surahs = []
for s in surah_index:
    sid = s['id']
    with open(f"chapters_en/{sid}.json") as f:
        ch = json.load(f)
    surahs.append({
        "id": sid,
        "name": s['name'],
        "transliteration": s['transliteration'],
        "translation": ch['translation'],
        "type": s['type'],
        "totalVerses": s['total_verses'],
        "startPage": page_map.get((sid, 1), 0)
    })

with open('surahs.json', 'w', encoding='utf-8') as f:
    json.dump(surahs, f, ensure_ascii=False, indent=2)
print(f"surahs.json: {len(surahs)} surahs")

# verses_hafs.json and verses_indopak.json
verses_hafs, verses_indopak = {}, {}
for sid in range(1, 115):
    with open(f"chapters_en/{sid}.json") as f:
        ch = json.load(f)
    hafs_list, ip_list = [], []
    ip_surah = indopak.get(str(sid), {})
    for v in ch['verses']:
        aid = v['id']
        page = page_map.get((sid, aid), 0)
        hafs_list.append({
            "id": aid,
            "text": v['text'],
            "translation": v['translation'],
            "transliteration": v.get('transliteration', ''),
            "page": page
        })
        ip_list.append({
            "id": aid,
            "text": ip_surah.get(str(aid), v['text']),
            "translation": v['translation'],
            "page": page
        })
    verses_hafs[str(sid)] = hafs_list
    verses_indopak[str(sid)] = ip_list

with open('verses_hafs.json', 'w', encoding='utf-8') as f:
    json.dump(verses_hafs, f, ensure_ascii=False)

with open('verses_indopak.json', 'w', encoding='utf-8') as f:
    json.dump(verses_indopak, f, ensure_ascii=False)

import os
for fname in ['surahs.json', 'verses_hafs.json', 'verses_indopak.json']:
    size = os.path.getsize(fname)
    print(f"{fname}: {size//1024}KB")

print("Done")
