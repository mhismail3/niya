#!/usr/bin/env python3
"""
build_dua.py — Merge Hisn al-Muslim + fitrahive data into dua_all.json

Primary: DataPrep/source/dua/husn_en.json (267 duas, 132 categories)
Supplementary: DataPrep/source/dua/fitrahive/*.json (97 duas, 5 categories)

Output: Niya/Resources/Data/dua_all.json
"""

import json
import os
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SOURCE_DIR = os.path.join(SCRIPT_DIR, "source", "dua")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "dua_all.json")

SECTION_MAP = [
    ("morning-evening", "Morning & Evening", [27, 28]),
    ("prayer-worship", "Prayer & Worship", list(range(14, 27)) + list(range(29, 32)) + [34]),
    ("sleep-waking", "Sleep & Waking", [32, 33] + list(range(100, 106))),
    ("home-daily", "Home & Daily Life", list(range(8, 14)) + list(range(35, 48))),
    ("food-drink", "Food & Drink", list(range(48, 53)) + [61, 62]),
    ("travel", "Travel", list(range(53, 61)) + list(range(63, 71))),
    ("health-hardship", "Health & Hardship", list(range(71, 83))),
    ("social-family", "Social & Family", list(range(83, 100))),
    ("hajj-umrah", "Hajj & Umrah", list(range(106, 119))),
    ("remembrance", "Remembrance & Forgiveness", list(range(119, 133))),
    ("waking-dress", "Waking Up & Getting Dressed", list(range(1, 8))),
]

LOWERCASE_WORDS = {
    'a', 'an', 'the', 'and', 'or', 'but', 'nor', 'for', 'so', 'yet',
    'in', 'on', 'at', 'to', 'of', 'by', 'from', 'with', 'as', 'is',
    'if', 'up', 'his', 'her', 'its',
}


def smart_title(text):
    """Title-case that keeps prepositions/articles lowercase and fixes possessives."""
    words = text.split()
    result = []
    for i, word in enumerate(words):
        lower = word.lower()
        if i == 0 or lower not in LOWERCASE_WORDS:
            titled = word.capitalize()
        else:
            titled = lower
        # Fix possessive 'S → 's (e.g. "Allah'S" → "Allah's")
        titled = re.sub(r"'S\b", "'s", titled)
        result.append(titled)
    return ' '.join(result)


def clean_text(text):
    """Clean up common text formatting issues."""
    text = re.sub(r' {2,}', ' ', text)  # collapse double spaces
    text = re.sub(r'(?i)\bpbuh\b', '(PBUH)', text)  # normalize PBUH
    text = text.strip()
    return text


DIACRITICS_RE = re.compile(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC'
    r'\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED\u08D3-\u08FF]'
)

def normalize_arabic(text):
    text = DIACRITICS_RE.sub('', text)
    text = re.sub(r'[إأآٱا]', 'ا', text)
    text = re.sub(r'[ىئ]', 'ي', text)
    text = re.sub(r'ة', 'ه', text)
    text = text.replace('\u0640', '')  # tatweel
    text = re.sub(r'[﴾﴿{}()\[\]«»]', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def extract_words(text):
    """Extract significant Arabic words (>=3 chars) from text."""
    norm = normalize_arabic(text)
    return [w for w in norm.split() if len(w) >= 3]


def load_hisn_references():
    """Load scraped hadith references from hisn_references.json."""
    path = os.path.join(SOURCE_DIR, "hisn_references.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def load_hisn_muslim():
    path = os.path.join(SOURCE_DIR, "husn_en.json")
    with open(path, encoding='utf-8-sig') as f:
        data = json.load(f)

    hisn_refs = load_hisn_references()
    chapters = data['English']
    categories = []
    all_duas = {}

    for ch in chapters:
        cat_id = ch['ID']
        cat_title = smart_title(ch['TITLE'].strip())

        duas = []
        for d in ch['TEXT']:
            arabic = d.get('ARABIC_TEXT') or d.get('Text') or ''
            transliteration = d.get('LANGUAGE_ARABIC_TRANSLATED_TEXT') or ''
            translation = d.get('TRANSLATED_TEXT') or ''
            repeat = d.get('REPEAT')

            arabic = arabic.strip()
            transliteration = clean_text(transliteration)
            translation = clean_text(translation)

            # Use transliteration as translation fallback for empty translations
            if not translation and transliteration:
                translation = transliteration

            if repeat is not None:
                try:
                    repeat = int(repeat)
                except (ValueError, TypeError):
                    repeat = None

            dua = {
                'id': d['ID'],
                'arabic': arabic,
                'translation': translation,
            }
            if transliteration:
                dua['transliteration'] = transliteration
            if repeat and repeat > 1:
                dua['repeat'] = repeat

            # Apply scraped hadith reference
            ref = hisn_refs.get(str(d['ID']))
            if ref:
                dua['source'] = ref

            duas.append(dua)

        categories.append({
            'id': cat_id,
            'name': cat_title,
            'totalDuas': len(duas),
        })
        all_duas[cat_id] = duas

    return categories, all_duas


def load_fitrahive():
    fitrahive_dir = os.path.join(SOURCE_DIR, "fitrahive")
    all_entries = []

    for fname in sorted(os.listdir(fitrahive_dir)):
        if not fname.endswith('.json'):
            continue
        path = os.path.join(fitrahive_dir, fname)
        with open(path, encoding='utf-8-sig') as f:
            entries = json.load(f)

        for entry in entries:
            item = {
                'arabic': entry.get('arabic', '').strip(),
                'translation': clean_text(entry.get('translation', '')),
                'transliteration': clean_text(entry.get('latin', '')),
                'source': clean_text(entry.get('source', '')) if entry.get('source') else None,
                'benefits': clean_text(entry.get('benefits') or entry.get('fawaid') or '') or None,
                'notes': clean_text(entry.get('notes', '')) if entry.get('notes') else None,
                'title': entry.get('title', '').strip(),
            }
            all_entries.append(item)

    return all_entries


def match_and_enrich(hisn_duas, fitrahive_entries):
    """Match fitrahive entries to Hisn al-Muslim duas using word-overlap similarity."""
    matched_count = 0
    unmatched_fitrahive = []

    # Pre-extract words for all Hisn duas
    hisn_index = []
    for cat_id, duas in hisn_duas.items():
        for i, dua in enumerate(duas):
            words = set(extract_words(dua['arabic']))
            hisn_index.append((cat_id, i, words))

    for entry in fitrahive_entries:
        fh_words = set(extract_words(entry['arabic']))
        if len(fh_words) < 2:
            unmatched_fitrahive.append(entry)
            continue

        best_match = None
        best_score = 0

        for cat_id, idx, h_words in hisn_index:
            if not h_words:
                continue
            overlap = len(fh_words & h_words)
            # Jaccard-like: overlap relative to the smaller set
            smaller = min(len(fh_words), len(h_words))
            if smaller == 0:
                continue
            score = overlap / smaller
            if score > best_score:
                best_score = score
                best_match = (cat_id, idx)

        if best_score >= 0.6 and best_match:
            cat_id, idx = best_match
            dua = hisn_duas[cat_id][idx]

            if entry['source'] and 'source' not in dua:
                dua['source'] = entry['source']
            if entry['benefits'] and 'benefits' not in dua:
                dua['benefits'] = entry['benefits']

            matched_count += 1
        else:
            unmatched_fitrahive.append(entry)

    print(f"  Matched {matched_count} fitrahive entries to Hisn al-Muslim")
    print(f"  Unmatched fitrahive entries: {len(unmatched_fitrahive)}")
    return unmatched_fitrahive


def assign_sections(categories, all_duas):
    assigned = set()
    for _, _, chapter_ids in SECTION_MAP:
        assigned.update(chapter_ids)

    all_cat_ids = {c['id'] for c in categories}
    unassigned = all_cat_ids - assigned
    if unassigned:
        print(f"  Warning: unassigned category IDs: {sorted(unassigned)}")

    sections = []
    for section_id, section_name, chapter_ids in SECTION_MAP:
        existing = [cid for cid in chapter_ids if cid in all_cat_ids]
        if existing:
            sections.append({
                'id': section_id,
                'name': section_name,
                'categoryIds': existing,
            })

    section_lookup = {}
    for section_id, _, chapter_ids in SECTION_MAP:
        for cid in chapter_ids:
            section_lookup[cid] = section_id

    for cat in categories:
        cat['sectionId'] = section_lookup.get(cat['id'], 'remembrance')

    return sections


def validate(categories, all_duas):
    errors = 0
    for cat_id, duas in all_duas.items():
        for dua in duas:
            if not dua.get('arabic'):
                print(f"  ERROR: dua {dua['id']} in category {cat_id} has empty arabic")
                errors += 1
            if not dua.get('translation'):
                print(f"  ERROR: dua {dua['id']} in category {cat_id} has empty translation")
                errors += 1
    return errors


def main():
    print("Loading Hisn al-Muslim...")
    categories, all_duas = load_hisn_muslim()
    print(f"  {len(categories)} categories, {sum(len(d) for d in all_duas.values())} duas")

    print("Loading fitrahive...")
    fitrahive = load_fitrahive()
    print(f"  {len(fitrahive)} entries")

    print("Matching and enriching...")
    unmatched = match_and_enrich(all_duas, fitrahive)

    if unmatched:
        next_cat_id = max(c['id'] for c in categories) + 1
        next_dua_id = max(d['id'] for duas in all_duas.values() for d in duas) + 1

        # Deduplicate unmatched entries by normalized Arabic
        seen = set()
        unique_unmatched = []
        for entry in unmatched:
            key = normalize_arabic(entry['arabic'])[:80]
            if key not in seen:
                seen.add(key)
                unique_unmatched.append(entry)

        selected_duas = []
        for entry in unique_unmatched:
            if not entry['arabic'] or not entry['translation']:
                continue
            dua = {
                'id': next_dua_id,
                'arabic': entry['arabic'],
                'translation': entry['translation'],
            }
            if entry['transliteration']:
                dua['transliteration'] = entry['transliteration']
            if entry['source']:
                dua['source'] = entry['source']
            if entry['benefits']:
                dua['benefits'] = entry['benefits']
            selected_duas.append(dua)
            next_dua_id += 1

        if selected_duas:
            categories.append({
                'id': next_cat_id,
                'name': 'Selected Duas',
                'sectionId': 'remembrance',
                'totalDuas': len(selected_duas),
            })
            all_duas[next_cat_id] = selected_duas
            print(f"  Added 'Selected Duas' category ({next_cat_id}) with {len(selected_duas)} entries")

    print("Assigning sections...")
    sections = assign_sections(categories, all_duas)
    print(f"  {len(sections)} sections")

    # Ensure Selected Duas category appears in a section
    selected_cat = next((c for c in categories if c['name'] == 'Selected Duas'), None)
    if selected_cat:
        for s in sections:
            if s['id'] == 'remembrance':
                if selected_cat['id'] not in s['categoryIds']:
                    s['categoryIds'].append(selected_cat['id'])

    print("Validating...")
    errors = validate(categories, all_duas)
    if errors:
        print(f"  {errors} validation errors!")
    else:
        print("  All entries valid.")

    duas_out = {str(k): v for k, v in all_duas.items()}

    output = {
        'sections': sections,
        'categories': sorted(categories, key=lambda c: c['id']),
        'duas': duas_out,
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, separators=(',', ':'))

    size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    total_duas = sum(len(d) for d in all_duas.values())
    print(f"\nWritten: {OUTPUT_PATH}")
    print(f"  {len(sections)} sections, {len(categories)} categories, {total_duas} duas")
    print(f"  Size: {size_kb:.0f} KB")


if __name__ == '__main__':
    main()
