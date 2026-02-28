#!/usr/bin/env python3
"""Merge hadith text + grades into bundle-ready JSON files."""
import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEXT_DIR = os.path.join(SCRIPT_DIR, "source", "hadith-json")
GRADE_DIR = os.path.join(SCRIPT_DIR, "source", "hadith-grades")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output", "hadith")
RESOURCES_DIR = os.path.join(SCRIPT_DIR, "..", "Niya", "Resources", "Data")

# Collection metadata: (ahmedbaset_filename, output_id, display_name, display_name_arabic, author)
COLLECTIONS = [
    ("bukhari", "bukhari", "Sahih al-Bukhari", "صحيح البخاري", "Imam al-Bukhari"),
    ("muslim", "muslim", "Sahih Muslim", "صحيح مسلم", "Imam Muslim"),
    ("abudawud", "abudawud", "Sunan Abu Dawud", "سنن أبي داود", "Imam Abu Dawud"),
    ("tirmidhi", "tirmidhi", "Jami' al-Tirmidhi", "جامع الترمذي", "Imam al-Tirmidhi"),
    ("nasai", "nasai", "Sunan an-Nasa'i", "سنن النسائي", "Imam an-Nasa'i"),
    ("ibnmajah", "ibnmajah", "Sunan Ibn Majah", "سنن ابن ماجه", "Imam Ibn Majah"),
    ("malik", "malik", "Muwatta Malik", "موطأ مالك", "Imam Malik"),
    ("ahmed", "ahmed", "Musnad Ahmad", "مسند أحمد", "Imam Ahmad ibn Hanbal"),
    ("darimi", "darimi", "Sunan al-Darimi", "سنن الدارمي", "Imam al-Darimi"),
    ("nawawi40", "nawawi", "40 Hadith Nawawi", "الأربعون النووية", "Imam al-Nawawi"),
    ("qudsi40", "qudsi", "40 Hadith Qudsi", "الأحاديث القدسية", ""),
    ("shahwaliullah40", "dehlawi", "40 Hadith Shah Waliullah", "الأربعون الولية", "Shah Waliullah Dehlawi"),
    ("aladab_almufrad", "aladab", "Al-Adab Al-Mufrad", "الأدب المفرد", "Imam al-Bukhari"),
    ("bulugh_almaram", "bulugh", "Bulugh al-Maram", "بلوغ المرام", "Ibn Hajar al-Asqalani"),
    ("mishkat_almasabih", "mishkat", "Mishkat al-Masabih", "مشكاة المصابيح", "Al-Tabrizi"),
    ("riyad_assalihin", "riyad", "Riyad as-Salihin", "رياض الصالحين", "Imam al-Nawawi"),
    ("shamail_muhammadiyah", "shamail", "Shamail Muhammadiyah", "الشمائل المحمدية", "Imam al-Tirmidhi"),
]

# Collections with grade data available (fawazahmed0 provides these)
GRADED_FILENAMES = {
    "bukhari", "muslim", "abudawud", "tirmidhi", "nasai",
    "ibnmajah", "malik", "nawawi40", "qudsi40", "shahwaliullah40",
}

GRADE_ARABIC = {
    "sahih": "صحيح",
    "hasan": "حسن",
    "daif": "ضعيف",
    "mawdu": "موضوع",
}


def normalize_grade(grade_str):
    """Pass through original grade string (normalization happens in Swift)."""
    if not grade_str:
        return None
    return grade_str.strip()


def grade_arabic(grade_str):
    """Return Arabic equivalent for known grade categories."""
    if not grade_str:
        return None
    g = grade_str.lower()
    if "mawdu" in g or "maudu" in g or "fabricat" in g:
        return GRADE_ARABIC["mawdu"]
    if "sahih" in g:
        return GRADE_ARABIC["sahih"]
    if "hasan" in g:
        return GRADE_ARABIC["hasan"]
    if "daif" in g or "da'if" in g or "weak" in g:
        return GRADE_ARABIC["daif"]
    return None


def load_grades(ahmedbaset_filename):
    """Load grades from fawazahmed0 data, indexed by hadith number."""
    grade_file = os.path.join(GRADE_DIR, f"{ahmedbaset_filename}.json")
    if not os.path.exists(grade_file):
        return {}
    with open(grade_file, encoding="utf-8") as f:
        raw = json.loads(f.read(), strict=False)
    grades = {}
    for h in raw.get("hadiths", []):
        num = h.get("hadithnumber")
        grade_list = h.get("grades", [])
        if grade_list and num is not None:
            # Use first grader's grade
            grades[num] = grade_list[0].get("grade", "")
    return grades


def normalize_chapters(raw_chapters, raw_hadiths):
    """Assign sequential IDs to chapters and remap hadith chapterIds.

    Fixes source data where some chapters have null IDs (e.g. Nasa'i "The Book
    of Agriculture") which causes JSONDecoder to fail on the non-optional Int.
    """
    id_map = {}
    null_chapter_new_ids = set()
    normalized = []

    for i, ch in enumerate(raw_chapters):
        new_id = i + 1
        old_id = ch.get("id")
        if old_id is not None:
            id_map[old_id] = new_id
        else:
            null_chapter_new_ids.add(new_id)
        normalized.append({
            **ch,
            "id": new_id,
        })

    # Remap hadith chapterIds
    remapped = []
    for h in raw_hadiths:
        cid = h.get("chapterId")
        if cid is None:
            # Assign to nearest null-origin chapter (first one)
            new_cid = min(null_chapter_new_ids) if null_chapter_new_ids else 0
        else:
            new_cid = id_map.get(cid, cid)
        remapped.append({**h, "chapterId": new_cid})

    return normalized, remapped


def build_collection(ahmedbaset_filename, output_id, has_grades):
    """Build a single collection's JSON file."""
    text_file = os.path.join(TEXT_DIR, f"{ahmedbaset_filename}.json")
    with open(text_file, encoding="utf-8") as f:
        raw = json.loads(f.read(), strict=False)

    grades = load_grades(ahmedbaset_filename) if has_grades else {}

    # Build chapters
    raw_chapters = raw.get("chapters", [])
    raw_hadiths = raw.get("hadiths", [])

    # Normalize chapter IDs (fix nulls, assign sequential)
    raw_chapters, raw_hadiths = normalize_chapters(raw_chapters, raw_hadiths)

    # Group hadiths by chapterId to compute ranges
    chapter_hadiths = {}
    for h in raw_hadiths:
        cid = h.get("chapterId") or 0
        chapter_hadiths.setdefault(cid, []).append(h)

    chapters = []
    for ch in raw_chapters:
        cid = ch["id"]
        ch_hadiths = chapter_hadiths.get(cid, [])
        if ch_hadiths:
            ids = [h["idInBook"] for h in ch_hadiths]
            hadith_range = [min(ids), max(ids)]
        else:
            hadith_range = []
        chapters.append({
            "id": cid,
            "title": ch.get("english", ""),
            "titleArabic": ch.get("arabic", ""),
            "hadithRange": hadith_range,
        })

    # Build hadiths
    hadiths = []
    for h in raw_hadiths:
        eng = h.get("english", {})
        if isinstance(eng, str):
            narrator = ""
            text = eng
        else:
            narrator = eng.get("narrator", "")
            text = eng.get("text", "")

        hadith_num = h.get("idInBook", h.get("id", 0))
        grade_str = grades.get(hadith_num) if has_grades else None

        hadiths.append({
            "id": hadith_num,
            "chapterId": h.get("chapterId") or 0,
            "arabic": h.get("arabic", ""),
            "narrator": narrator,
            "text": text,
            "grade": normalize_grade(grade_str),
            "gradeArabic": grade_arabic(grade_str),
        })

    return {
        "chapters": chapters,
        "hadiths": hadiths,
    }


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    collections_index = []

    for ahmedbaset_filename, output_id, name, name_ar, author in COLLECTIONS:
        text_file = os.path.join(TEXT_DIR, f"{ahmedbaset_filename}.json")
        if not os.path.exists(text_file):
            print(f"SKIP (missing): {ahmedbaset_filename}")
            continue

        has_grades = ahmedbaset_filename in GRADED_FILENAMES
        data = build_collection(ahmedbaset_filename, output_id, has_grades)

        # Write per-collection file
        out_path = os.path.join(OUTPUT_DIR, f"hadith_{output_id}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        size_kb = os.path.getsize(out_path) // 1024
        print(f"hadith_{output_id}.json: {len(data['hadiths'])} hadiths, {len(data['chapters'])} chapters, {size_kb}KB")

        collections_index.append({
            "id": output_id,
            "name": name,
            "nameArabic": name_ar,
            "author": author,
            "totalHadiths": len(data["hadiths"]),
            "totalChapters": len(data["chapters"]),
            "hasGrades": has_grades,
        })

    # Write collections index
    index_path = os.path.join(OUTPUT_DIR, "hadith_collections.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(collections_index, f, ensure_ascii=False, indent=2)
    print(f"\nhadith_collections.json: {len(collections_index)} collections")

    # Copy to Niya/Resources/Data/
    os.makedirs(RESOURCES_DIR, exist_ok=True)
    import shutil
    for fname in os.listdir(OUTPUT_DIR):
        if fname.endswith(".json"):
            src = os.path.join(OUTPUT_DIR, fname)
            dst = os.path.join(RESOURCES_DIR, fname)
            shutil.copy2(src, dst)
            print(f"Copied: {fname} -> Niya/Resources/Data/")

    total_hadiths = sum(c["totalHadiths"] for c in collections_index)
    print(f"\nTotal: {total_hadiths} hadiths across {len(collections_index)} collections")


if __name__ == "__main__":
    main()
