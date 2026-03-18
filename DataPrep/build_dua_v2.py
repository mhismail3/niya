#!/usr/bin/env python3
"""
build_dua_v2.py — Comprehensive dua collection builder (v2).

Merges:
1. Hisn al-Muslim (267 duas, 132 categories) — primary English source
2. azkar-db (345 Arabic azkar) — Arabic-only additions
3. fitrahive (97 duas, 5 categories) — enrichment + unique additions
4. Quranic duas (~85 extracted supplications) — new section

Output:
- Niya/Resources/Data/dua_all.json (new schema with string IDs)
- Niya/Resources/Data/dua_id_migration.json (old→new key mapping)
"""

import json
import os
import re
import unicodedata

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SOURCE_DIR = os.path.join(SCRIPT_DIR, "source", "dua")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "dua_all.json")
MIGRATION_PATH = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "dua_id_migration.json")

# ---------------------------------------------------------------------------
# Text utilities (carried from build_dua.py)
# ---------------------------------------------------------------------------

LOWERCASE_WORDS = {
    'a', 'an', 'the', 'and', 'or', 'but', 'nor', 'for', 'so', 'yet',
    'in', 'on', 'at', 'to', 'of', 'by', 'from', 'with', 'as', 'is',
    'if', 'up', 'his', 'her', 'its',
}


def smart_title(text):
    words = text.split()
    result = []
    for i, word in enumerate(words):
        lower = word.lower()
        if i == 0 or lower not in LOWERCASE_WORDS:
            titled = word.capitalize()
        else:
            titled = lower
        titled = re.sub(r"'S\b", "'s", titled)
        result.append(titled)
    return ' '.join(result)


def strip_outer_parens(text):
    """Remove outermost wrapping parentheses from a string."""
    while text.startswith('(') and text.endswith(')'):
        text = text[1:-1].strip()
    return text


def clean_text(text):
    if not text:
        return ""
    text = re.sub(r' {2,}', ' ', text)
    text = re.sub(r'(?i)\bpbuh\b', '(PBUH)', text)
    return text.strip()


DIACRITICS_RE = re.compile(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC'
    r'\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED\u08D3-\u08FF]'
)


def normalize_arabic(text):
    text = DIACRITICS_RE.sub('', text)
    text = re.sub(r'[إأآٱا]', 'ا', text)
    text = re.sub(r'[ىئ]', 'ي', text)
    text = re.sub(r'ة', 'ه', text)
    text = text.replace('\u0640', '')
    text = re.sub(r'[﴾﴿{}()\[\]«»]', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def extract_words(text):
    norm = normalize_arabic(text)
    return [w for w in norm.split() if len(w) >= 3]


def slugify(text):
    text = text.lower().strip()
    text = unicodedata.normalize('NFKD', text)
    text = text.encode('ascii', 'ignore').decode('ascii')
    text = re.sub(r'[^a-z0-9]+', '-', text)
    text = text.strip('-')
    return text or "untitled"


# ---------------------------------------------------------------------------
# Reference normalization
# ---------------------------------------------------------------------------

COLLECTION_NAMES = {
    "bukhari": "Sahih al-Bukhari",
    "al-bukhari": "Sahih al-Bukhari",
    "muslim": "Sahih Muslim",
    "abu dawud": "Abu Dawud",
    "tirmidhi": "At-Tirmidhi",
    "at-tirmidhi": "At-Tirmidhi",
    "nasa'i": "An-Nasa'i",
    "an-nasa'i": "An-Nasa'i",
    "ibn majah": "Ibn Majah",
    "ahmad": "Musnad Ahmad",
    "malik": "Muwatta Malik",
    "hakim": "Al-Hakim",
    "al-hakim": "Al-Hakim",
    "bayhaqi": "Al-Bayhaqi",
    "al-bayhaqi": "Al-Bayhaqi",
    "tabarani": "At-Tabarani",
    "at-tabarani": "At-Tabarani",
    "ibn hibban": "Ibn Hibban",
    "darimi": "Ad-Darimi",
}


def normalize_reference(ref):
    """Best-effort normalization of hadith references."""
    if not ref:
        return None
    ref = clean_text(ref)
    if ref.startswith("Quran") or ref.startswith("Qur'an"):
        return ref
    return ref


# ---------------------------------------------------------------------------
# Hisn category → new section/category mapping
# ---------------------------------------------------------------------------

# Maps old Hisn chapter IDs to new section slugs.
# This is the reorganized structure from the plan.
HISN_SECTION_MAP = {
    # Morning & Evening
    27: "morning-evening", 28: "morning-evening",
    # Sleep & Waking
    32: "sleep-waking", 33: "sleep-waking",
    100: "sleep-waking", 101: "sleep-waking", 102: "sleep-waking",
    103: "sleep-waking", 104: "sleep-waking", 105: "sleep-waking",
    # Waking & Dressing (merged into Daily Life)
    1: "daily-life", 2: "daily-life", 3: "daily-life",
    4: "daily-life", 5: "daily-life", 6: "daily-life", 7: "daily-life",
    # Home & Daily Life
    8: "daily-life", 9: "daily-life", 10: "daily-life", 11: "daily-life",
    12: "daily-life", 13: "daily-life",
    35: "daily-life", 36: "daily-life", 37: "daily-life", 38: "daily-life",
    39: "daily-life", 40: "daily-life", 41: "daily-life", 42: "daily-life",
    43: "daily-life", 44: "daily-life", 45: "daily-life", 46: "daily-life",
    47: "daily-life",
    # Prayer & Worship
    14: "prayer-worship", 15: "prayer-worship", 16: "prayer-worship",
    17: "prayer-worship", 18: "prayer-worship", 19: "prayer-worship",
    20: "prayer-worship", 21: "prayer-worship", 22: "prayer-worship",
    23: "prayer-worship", 24: "prayer-worship", 25: "prayer-worship",
    26: "prayer-worship", 29: "prayer-worship", 30: "prayer-worship",
    31: "prayer-worship", 34: "prayer-worship",
    # Food & Fasting
    48: "food-fasting", 49: "food-fasting", 50: "food-fasting",
    51: "food-fasting", 52: "food-fasting",
    61: "food-fasting", 62: "food-fasting",
    # Travel
    53: "travel", 54: "travel", 55: "travel", 56: "travel",
    57: "travel", 58: "travel", 59: "travel", 60: "travel",
    63: "travel", 64: "travel", 65: "travel", 66: "travel",
    67: "travel", 68: "travel", 69: "travel", 70: "travel",
    # Health & Protection
    71: "protection-healing", 72: "protection-healing", 73: "protection-healing",
    74: "protection-healing", 75: "protection-healing", 76: "protection-healing",
    77: "protection-healing", 78: "protection-healing", 79: "protection-healing",
    80: "protection-healing", 81: "protection-healing", 82: "protection-healing",
    # Social & Family
    83: "social-family", 84: "social-family", 85: "social-family",
    86: "social-family", 87: "social-family", 88: "social-family",
    89: "social-family", 90: "social-family", 91: "social-family",
    92: "social-family", 93: "social-family", 94: "social-family",
    95: "social-family", 96: "social-family", 97: "social-family",
    98: "social-family", 99: "social-family",
    # Hajj & Umrah
    106: "hajj-umrah", 107: "hajj-umrah", 108: "hajj-umrah",
    109: "hajj-umrah", 110: "hajj-umrah", 111: "hajj-umrah",
    112: "hajj-umrah", 113: "hajj-umrah", 114: "hajj-umrah",
    115: "hajj-umrah", 116: "hajj-umrah", 117: "hajj-umrah",
    118: "hajj-umrah",
    # Remembrance & Dhikr
    119: "remembrance-dhikr", 120: "remembrance-dhikr", 121: "remembrance-dhikr",
    122: "remembrance-dhikr", 123: "remembrance-dhikr", 124: "remembrance-dhikr",
    125: "remembrance-dhikr", 126: "remembrance-dhikr", 127: "remembrance-dhikr",
    128: "remembrance-dhikr", 129: "remembrance-dhikr", 130: "remembrance-dhikr",
    131: "remembrance-dhikr", 132: "remembrance-dhikr",
}

# Azkar-db Arabic category → section mapping
AZKAR_SECTION_MAP = {
    "أذكار الصباح": "morning-evening",
    "أذكار المساء": "morning-evening",
    "أذكار النوم": "sleep-waking",
    "أذكار الاستيقاظ من النوم": "sleep-waking",
    "من تعار من الليل": "sleep-waking",
    "دعاء الفزع في النوم و من بلي بالوحشة": "sleep-waking",
    "أذكار الآذان": "prayer-worship",
    "الأذكار بعد السلام من الصلاة": "prayer-worship",
    "الدعاء بعد التشهد الأخير قبل السلام": "prayer-worship",
    "التشهد": "prayer-worship",
    "الصلاة على النبي بعد التشهد": "prayer-worship",
    "دعاء الاستفتاح": "prayer-worship",
    "دعاء الجلسة بين السجدتين": "prayer-worship",
    "دعاء الرفع من الركوع": "prayer-worship",
    "دعاء الركوع": "prayer-worship",
    "دعاء السجود": "prayer-worship",
    "دعاء سجود التلاوة": "prayer-worship",
    "دعاء صلاة الاستخارة": "prayer-worship",
    "دعاء قنوت الوتر": "prayer-worship",
    "الذكر عقب السلام من الوتر": "prayer-worship",
    "دعاء الوسوسة في الصلاة و القراءة": "prayer-worship",
    "الذكر بعد الفراغ من الوضوء": "prayer-worship",
    "الذكر قبل الوضوء": "prayer-worship",
    "دعاء الذهاب إلى المسجد": "prayer-worship",
    "دعاء دخول المسجد": "prayer-worship",
    "دعاء الخروج من المسجد": "prayer-worship",
    "فضل الصلاة على النبي صلى الله عليه و سلم": "remembrance-dhikr",
    "الاستغفار و التوبة": "remembrance-dhikr",
    "التسبيح، التحميد، التهليل، التكبير": "remembrance-dhikr",
    "كفارة اﻟﻤﺠلس": "remembrance-dhikr",
    "ما يقال في اﻟﻤﺠلس": "remembrance-dhikr",
    "كيف كان النبي يسبح؟": "remembrance-dhikr",
    "ما يقول ويفعل من أذنب ذنبا": "remembrance-dhikr",
    "من أنواع الخير والآداب الجامعة": "remembrance-dhikr",
    "الذكر عند دخول المنزل": "daily-life",
    "الذكر عند الخروج من المنزل": "daily-life",
    "دعاء دخول الخلاء": "daily-life",
    "دعاء الخروج من الخلاء": "daily-life",
    "دعاء لبس الثوب": "daily-life",
    "دعاء لبس الثوب الجديد": "daily-life",
    "ما يقول إذا وضع الثوب": "daily-life",
    "دعاء دخول السوق": "daily-life",
    "دعاء دخول القرية أو البلدة": "daily-life",
    "الدعاء قبل الطعام": "food-fasting",
    "الدعاء عند الفراغ من الطعام": "food-fasting",
    "الدعاء عند إفطار الصائم": "food-fasting",
    "دعاء الصائم إذا حضر الطعام ولم يفطر": "food-fasting",
    "الدعاء إذا أفطر عند أهل بيت": "food-fasting",
    "دعاء الضيف لصاحب الطعام": "food-fasting",
    "التعريض بالدعاء لطلب الطعام أو الشراب": "food-fasting",
    "ما يقول الصائم إذا سابه أحد": "food-fasting",
    "دعاء السفر": "travel",
    "دعاء الركوب": "travel",
    "الدعاء إذا تعس المركوب": "travel",
    "دعاء المسافر إذا أسحر": "travel",
    "دعاء المسافر للمقيم": "travel",
    "دعاء المقيم للمسافر": "travel",
    "التكبير و التسبيح في سير السفر": "travel",
    "الدعاء إذا نزل مترلا في سفر أو غيره": "travel",
    "ذكر الرجوع من السفر": "travel",
    "الرقية الشرعية من السنة النبوية": "protection-healing",
    "الرقية الشرعية من القرآن الكريم": "protection-healing",
    "دعاء الكرب": "protection-healing",
    "دعاء الهم والحزن": "protection-healing",
    "دعاء الغضب": "protection-healing",
    "دعاء طرد الشيطان و وساوسه": "protection-healing",
    "دعاء الخوف من الشرك": "protection-healing",
    "دعاء من أصابه وسوسة في الإيمان": "protection-healing",
    "دعاء من أصيب بمصيبة": "protection-healing",
    "دعاء من استصعب عليه أمر": "protection-healing",
    "الدعاء حينما يقع ما لا يرضاه أو غلب على أمره": "protection-healing",
    "ما يعوذ به الأولاد": "protection-healing",
    "ما يقول من أحس وجعا في جسده": "protection-healing",
    "دعاء من خشي أن يصيب شيئا بعينه": "protection-healing",
    "ما يعصم الله به من الدجال": "protection-healing",
    "دعاء نباح الكلب بالليل": "protection-healing",
    "ما يقول لرد كيد مردة الشياطين": "protection-healing",
    "ما يقال عند الفزع": "protection-healing",
    "دعاء كراهية الطيرة": "protection-healing",
    "الدعاء للمريض في عيادته": "social-family",
    "فضل عيادة المريض": "social-family",
    "دعاء المريض الذي يئس من حياته": "social-family",
    "الدعاء للمتزوج": "social-family",
    "دعاء المتزوج و شراء الدابة": "social-family",
    "الدعاء لمن صنع إليك معروفا": "social-family",
    "الدعاء لمن قال إني أحبك في الله": "social-family",
    "الدعاء لمن قال بارك الله فيك": "social-family",
    "الدعاء لمن قال غفر الله لك": "social-family",
    "الدعاء لمن عرض عليك ماله": "social-family",
    "الدعاء لمن سببته": "social-family",
    "دعاء العطاس": "social-family",
    "إفشاء السلام": "social-family",
    "كيف يرد السلام على الكافر إذا سلم": "social-family",
    "ما يقال للكافر إذا عطس فحمد الله": "social-family",
    "ما يقول المسلم إذا زكي": "social-family",
    "ما يقول المسلم إذا مدح المسلم": "social-family",
    "دعاء لقاء العدو و ذي السلطان": "social-family",
    "ما يقول من خاف قوما": "social-family",
    "الدعاء على العدو": "social-family",
    "ﺗﻬنئة المولود له وجوابه": "social-family",
    "دعاء من رأى مبتلى": "social-family",
    "تلقين المحتضر": "social-family",
    "الدعاء عند إغماض الميت": "social-family",
    "الدعاء للميت في الصلاة عليه": "social-family",
    "الدعاء للفرط في الصلاة عليه": "social-family",
    "الدعاء عند إدخال الميت القبر": "social-family",
    "الدعاء بعد دفن الميت": "social-family",
    "دعاء زيارة القبور": "social-family",
    "دعاء التعجب والأمر السار": "social-family",
    "دعاء التعزية": "social-family",
    "ما يفعل من أتاه أمر يسره": "social-family",
    "ما يقول من أتاه أمر يسره أو يكرهه": "social-family",
    "دعاء لمن أقرض عند القضاء": "social-family",
    "دعاء قضاء الدين": "protection-healing",
    "الدعاء إذا تقلب في الليل": "sleep-waking",
    "ما يفعل من رأى الرؤيا أو الحلم في النوم": "sleep-waking",
    # Hajj
    "التكبير إذا أتى الركن الأسود": "hajj-umrah",
    "التكبير عند رمي الجمار مع كل حصاة": "hajj-umrah",
    "الدعاء بين الركن اليماني والحجر الأسود": "hajj-umrah",
    "الذكر عند المشعر الحرام": "hajj-umrah",
    "دعاء الوقوف على الصفا والمروة": "hajj-umrah",
    "دعاء يوم عرفة": "hajj-umrah",
    "كيف يلبي المحرم في الحج أو العمرة ؟": "hajj-umrah",
    # Weather
    "الدعاء إذا نزل المطر": "weather-nature",
    "الذكر بعد نزول المطر": "weather-nature",
    "من أدعية الاستسقاء": "weather-nature",
    "من أدعية الاستصحاء": "weather-nature",
    "دعاء الرعد": "weather-nature",
    "دعاء الريح": "weather-nature",
    "دعاء رؤية الهلال": "weather-nature",
    "دعاء عند رؤية باكورة الثمر": "weather-nature",
    # Places & Times
    "أماكن وأوقات إجابة الدعاء ": "remembrance-dhikr",
    "ما يقول عند الذبح أو النحر": "food-fasting",
    "الدعاء قبل إتيان الزوجة": "social-family",
}

# New section definitions (order matters for output)
SECTIONS = [
    ("morning-evening", "Morning & Evening"),
    ("prayer-worship", "Prayer & Worship"),
    ("quranic-rabbana", "Rabbana Duas"),
    ("quranic-rabbi", "Rabbi Duas"),
    ("quranic-other", "Other Quranic Duas"),
    ("sleep-waking", "Sleep & Waking"),
    ("daily-life", "Daily Life"),
    ("food-fasting", "Food & Fasting"),
    ("travel", "Travel"),
    ("social-family", "Social & Family"),
    ("protection-healing", "Protection & Healing"),
    ("remembrance-dhikr", "Remembrance & Dhikr"),
    ("hajj-umrah", "Hajj & Umrah"),
    ("weather-nature", "Weather & Nature"),
]


# ---------------------------------------------------------------------------
# Load sources
# ---------------------------------------------------------------------------

def load_hisn_references():
    path = os.path.join(SOURCE_DIR, "hisn_references.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def load_fitrahive_references():
    path = os.path.join(SOURCE_DIR, "fitrahive_references.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    return data.get("sources", {})


def load_hisn_muslim():
    path = os.path.join(SOURCE_DIR, "husn_en.json")
    with open(path, encoding='utf-8-sig') as f:
        data = json.load(f)

    hisn_refs = load_hisn_references()
    fh_refs = load_fitrahive_references()
    chapters = data['English']
    categories = []
    all_duas = {}

    for ch in chapters:
        old_cat_id = ch['ID']
        cat_title = smart_title(ch['TITLE'].strip())
        cat_slug = slugify(cat_title)
        section_id = HISN_SECTION_MAP.get(old_cat_id, "remembrance-dhikr")

        duas = []
        for d in ch['TEXT']:
            old_dua_id = d['ID']
            arabic = (d.get('ARABIC_TEXT') or d.get('Text') or '').strip()
            transliteration = clean_text(d.get('LANGUAGE_ARABIC_TRANSLATED_TEXT') or '')
            translation = strip_outer_parens(clean_text(d.get('TRANSLATED_TEXT') or ''))

            if not translation and transliteration:
                translation = strip_outer_parens(transliteration)

            repeat = d.get('REPEAT')
            if repeat is not None:
                try:
                    repeat = int(repeat)
                except (ValueError, TypeError):
                    repeat = None

            dua_id = f"hisn-{old_dua_id}"

            dua = {
                'id': dua_id,
                'arabic': arabic,
                'translation': translation,
                '_old_cat_id': old_cat_id,
                '_old_dua_id': old_dua_id,
            }
            if transliteration:
                dua['transliteration'] = transliteration
            if repeat and repeat > 1:
                dua['repeat'] = repeat

            # Apply hadith reference
            ref = hisn_refs.get(str(old_dua_id))
            if ref:
                dua['reference'] = normalize_reference(ref)

            # Apply fitrahive reference
            fh_ref = fh_refs.get(str(old_dua_id))
            if fh_ref and 'reference' not in dua:
                dua['reference'] = normalize_reference(fh_ref)

            duas.append(dua)

        categories.append({
            'id': cat_slug,
            'name': cat_title,
            'sectionId': section_id,
            'totalDuas': len(duas),
            '_old_id': old_cat_id,
        })
        all_duas[cat_slug] = duas

    return categories, all_duas


def load_azkar_db():
    path = os.path.join(SOURCE_DIR, "azkar_db.json")
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    rows = data.get('rows', [])
    entries = []
    for row in rows:
        category_ar = (row[0] or "").strip()
        zekr = (row[1] or "").strip()
        description = (row[2] or "").strip()
        count = row[3] if len(row) > 3 else None
        reference = (row[4] or "").strip() if len(row) > 4 else ""
        if not zekr:
            continue
        entries.append({
            'category_ar': category_ar,
            'arabic': zekr,
            'description_ar': description,
            'count': count,
            'reference': reference,
        })
    return entries


def load_fitrahive():
    fitrahive_dir = os.path.join(SOURCE_DIR, "fitrahive")
    if not os.path.isdir(fitrahive_dir):
        return []
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
                'translation': strip_outer_parens(clean_text(entry.get('translation', ''))),
                'transliteration': strip_outer_parens(clean_text(entry.get('latin', ''))),
                'source': clean_text(entry.get('source', '')) if entry.get('source') else None,
                'benefits': clean_text(entry.get('benefits') or entry.get('fawaid') or '') or None,
            }
            all_entries.append(item)
    return all_entries


def load_quranic_duas():
    path = os.path.join(SOURCE_DIR, "quranic_duas_extracted.json")
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8') as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Merging logic
# ---------------------------------------------------------------------------

def build_hisn_word_index(all_duas):
    """Pre-compute normalized Arabic words for all Hisn duas."""
    index = []
    for cat_slug, duas in all_duas.items():
        for i, dua in enumerate(duas):
            words = set(extract_words(dua['arabic']))
            index.append((cat_slug, i, words))
    return index


def merge_fitrahive(all_duas, fitrahive_entries):
    """Match fitrahive entries to Hisn duas, enrich with source/benefits."""
    hisn_index = build_hisn_word_index(all_duas)
    matched = 0
    unmatched = []

    for entry in fitrahive_entries:
        fh_words = set(extract_words(entry['arabic']))
        if len(fh_words) < 2:
            unmatched.append(entry)
            continue

        best_match = None
        best_score = 0
        for cat_slug, idx, h_words in hisn_index:
            if not h_words:
                continue
            overlap = len(fh_words & h_words)
            smaller = min(len(fh_words), len(h_words))
            if smaller == 0:
                continue
            score = overlap / smaller
            if score > best_score:
                best_score = score
                best_match = (cat_slug, idx)

        if best_score >= 0.6 and best_match:
            cat_slug, idx = best_match
            dua = all_duas[cat_slug][idx]
            if entry['source'] and 'reference' not in dua:
                dua['reference'] = normalize_reference(entry['source'])
            if entry['benefits'] and 'benefits' not in dua:
                dua['benefits'] = entry['benefits']
            matched += 1
        else:
            unmatched.append(entry)

    print(f"  Matched {matched} fitrahive entries to Hisn")
    print(f"  Unmatched: {len(unmatched)}")
    return unmatched


def merge_azkar_db(categories, all_duas, azkar_entries):
    """Merge azkar-db entries: dedup against Hisn, add unique as arabicOnly."""
    hisn_index = build_hisn_word_index(all_duas)
    new_entries_by_section = {}
    matched = 0
    azkar_counter = 0

    for entry in azkar_entries:
        entry_words = set(extract_words(entry['arabic']))
        if len(entry_words) < 2:
            continue

        # Check for duplicate against Hisn
        best_score = 0
        for _, _, h_words in hisn_index:
            if not h_words:
                continue
            overlap = len(entry_words & h_words)
            smaller = min(len(entry_words), len(h_words))
            if smaller == 0:
                continue
            score = overlap / smaller
            if score > best_score:
                best_score = score

        if best_score >= 0.6:
            matched += 1
            continue

        # New unique entry
        azkar_counter += 1
        section_id = AZKAR_SECTION_MAP.get(entry['category_ar'], 'remembrance-dhikr')

        dua = {
            'id': f"azkar-{azkar_counter}",
            'arabic': entry['arabic'],
            'arabicOnly': True,
        }
        if entry.get('description_ar'):
            dua['context'] = entry['description_ar']
        if entry.get('count') and entry['count'] > 1:
            dua['repeat'] = entry['count']
        if entry.get('reference'):
            dua['reference'] = entry['reference']

        if section_id not in new_entries_by_section:
            new_entries_by_section[section_id] = []
        new_entries_by_section[section_id].append(dua)

    # Create categories for azkar entries grouped by section
    for section_id, entries in new_entries_by_section.items():
        cat_slug = f"azkar-{section_id}"
        section_name = next((n for sid, n in SECTIONS if sid == section_id), section_id)
        cat_name = f"{section_name} Azkar"

        categories.append({
            'id': cat_slug,
            'name': cat_name,
            'sectionId': section_id,
            'totalDuas': len(entries),
        })
        all_duas[cat_slug] = entries

    total_new = sum(len(e) for e in new_entries_by_section.values())
    print(f"  Matched {matched} azkar-db entries against Hisn (deduped)")
    print(f"  Added {total_new} unique azkar entries in {len(new_entries_by_section)} new categories")
    return total_new


def add_unmatched_fitrahive(categories, all_duas, unmatched):
    """Add unmatched fitrahive entries as 'Selected Duas' category."""
    seen = set()
    unique = []
    for entry in unmatched:
        key = normalize_arabic(entry['arabic'])[:80]
        if key not in seen and entry['arabic'] and entry['translation']:
            seen.add(key)
            unique.append(entry)

    if not unique:
        return 0

    fh_counter = 0
    selected_duas = []
    for entry in unique:
        fh_counter += 1
        dua = {
            'id': f"fh-{fh_counter}",
            'arabic': entry['arabic'],
            'translation': entry['translation'],
        }
        if entry.get('transliteration'):
            dua['transliteration'] = entry['transliteration']
        if entry.get('source'):
            dua['reference'] = normalize_reference(entry['source'])
        if entry.get('benefits'):
            dua['benefits'] = entry['benefits']
        selected_duas.append(dua)

    cat_slug = "selected-duas"
    categories.append({
        'id': cat_slug,
        'name': 'Selected Duas',
        'sectionId': 'remembrance-dhikr',
        'totalDuas': len(selected_duas),
    })
    all_duas[cat_slug] = selected_duas
    print(f"  Added {len(selected_duas)} fitrahive unique entries as 'Selected Duas'")
    return len(selected_duas)


def add_quranic_duas(categories, all_duas, quranic):
    """Add Quranic duas as 3 categories: Rabbana, Rabbi, Other."""
    by_cat = {'rabbana': [], 'rabbi': [], 'essential': [], 'protection': [], 'other': []}
    quranic_counter = 0

    for entry in quranic:
        quranic_counter += 1
        cat = entry['category']
        s = entry['surah']
        ayahs = entry['ayahs']
        ayah_str = str(ayahs[0]) if len(ayahs) == 1 else f"{ayahs[0]}-{ayahs[-1]}"

        dua = {
            'id': f"quran-{s}-{ayah_str}",
            'arabic': entry['arabic'],
            'translation': entry['translation'],
            'reference': entry['reference'],
        }
        if entry.get('transliteration'):
            dua['transliteration'] = entry['transliteration']
        if entry.get('note'):
            dua['context'] = entry['note']

        if cat in by_cat:
            by_cat[cat].append(dua)
        else:
            by_cat['other'].append(dua)

    # Merge essential + protection + other into "other"
    by_cat['other'] = by_cat['essential'] + by_cat['protection'] + by_cat['other']
    del by_cat['essential']
    del by_cat['protection']

    cat_configs = [
        ('quranic-rabbana', 'Rabbana Duas (Our Lord)', 'quranic-rabbana', by_cat['rabbana']),
        ('quranic-rabbi', 'Rabbi Duas (My Lord)', 'quranic-rabbi', by_cat['rabbi']),
        ('quranic-other', 'Other Quranic Supplications', 'quranic-other', by_cat['other']),
    ]

    total = 0
    for cat_slug, cat_name, section_id, duas in cat_configs:
        if not duas:
            continue
        categories.append({
            'id': cat_slug,
            'name': cat_name,
            'sectionId': section_id,
            'totalDuas': len(duas),
        })
        all_duas[cat_slug] = duas
        total += len(duas)

    print(f"  Added {total} Quranic duas in 3 categories")
    return total


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------

def build_sections(categories):
    """Assemble sections from categories, respecting SECTIONS order."""
    cat_by_section = {}
    for cat in categories:
        sid = cat['sectionId']
        if sid not in cat_by_section:
            cat_by_section[sid] = []
        cat_by_section[sid].append(cat['id'])

    sections = []
    for section_id, section_name in SECTIONS:
        cat_ids = cat_by_section.get(section_id, [])
        if cat_ids:
            sections.append({
                'id': section_id,
                'name': section_name,
                'categoryIds': cat_ids,
            })

    # Check for orphan sections
    known = {sid for sid, _ in SECTIONS}
    for sid in cat_by_section:
        if sid not in known:
            print(f"  WARNING: unknown section '{sid}' with {len(cat_by_section[sid])} categories")

    return sections


def build_migration_map(categories, all_duas):
    """Build old "catId:duaId" → new "catSlug:duaStringId" mapping."""
    migration = {}
    for cat in categories:
        old_cat_id = cat.get('_old_id')
        if old_cat_id is None:
            continue
        cat_slug = cat['id']
        for dua in all_duas.get(cat_slug, []):
            old_dua_id = dua.get('_old_dua_id')
            if old_dua_id is None:
                continue
            old_key = f"{old_cat_id}:{old_dua_id}"
            new_key = f"{cat_slug}:{dua['id']}"
            migration[old_key] = new_key
    return migration


def strip_internal_fields(all_duas):
    """Remove _old_* fields from dua entries."""
    internal = {'_old_cat_id', '_old_dua_id'}
    for cat_slug, duas in all_duas.items():
        for dua in duas:
            for key in internal:
                dua.pop(key, None)


def strip_category_internal(categories):
    """Remove _old_id from categories."""
    for cat in categories:
        cat.pop('_old_id', None)


def validate(all_duas):
    errors = 0
    for cat_slug, duas in all_duas.items():
        for dua in duas:
            if not dua.get('arabic'):
                print(f"  ERROR: dua {dua['id']} in {cat_slug} has empty arabic")
                errors += 1
            if not dua.get('translation') and not dua.get('arabicOnly'):
                print(f"  ERROR: dua {dua['id']} in {cat_slug} has empty translation and not arabicOnly")
                errors += 1
    return errors


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=== Dua Collection Builder v2 ===\n")

    print("Loading Hisn al-Muslim...")
    categories, all_duas = load_hisn_muslim()
    print(f"  {len(categories)} categories, {sum(len(d) for d in all_duas.values())} duas")

    print("Loading fitrahive...")
    fitrahive = load_fitrahive()
    print(f"  {len(fitrahive)} entries")

    print("Matching fitrahive...")
    unmatched_fh = merge_fitrahive(all_duas, fitrahive)

    print("Adding unmatched fitrahive...")
    add_unmatched_fitrahive(categories, all_duas, unmatched_fh)

    print("Loading azkar-db...")
    azkar = load_azkar_db()
    print(f"  {len(azkar)} entries")

    print("Merging azkar-db...")
    merge_azkar_db(categories, all_duas, azkar)

    print("Loading Quranic duas...")
    quranic = load_quranic_duas()
    print(f"  {len(quranic)} extracted")

    print("Adding Quranic duas...")
    add_quranic_duas(categories, all_duas, quranic)

    print("\nBuilding migration map...")
    migration = build_migration_map(categories, all_duas)
    print(f"  {len(migration)} old→new key mappings")

    # Clean up internal fields
    strip_internal_fields(all_duas)
    strip_category_internal(categories)

    print("Building sections...")
    sections = build_sections(categories)
    print(f"  {len(sections)} sections")

    # Update totalDuas counts
    for cat in categories:
        cat['totalDuas'] = len(all_duas.get(cat['id'], []))

    print("\nValidating...")
    errors = validate(all_duas)
    if errors:
        print(f"  {errors} validation errors!")
    else:
        print("  All entries valid.")

    # Output
    output = {
        'version': 2,
        'sections': sections,
        'categories': categories,
        'duas': all_duas,
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, separators=(',', ':'))

    with open(MIGRATION_PATH, 'w', encoding='utf-8') as f:
        json.dump(migration, f, ensure_ascii=False, indent=2)

    total_duas = sum(len(d) for d in all_duas.values())
    size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    migration_size = os.path.getsize(MIGRATION_PATH) / 1024

    print(f"\n=== Output ===")
    print(f"  dua_all.json: {len(sections)} sections, {len(categories)} categories, {total_duas} duas ({size_kb:.0f} KB)")
    print(f"  dua_id_migration.json: {len(migration)} mappings ({migration_size:.0f} KB)")

    # Section breakdown
    print(f"\n=== Section Breakdown ===")
    for section in sections:
        cat_ids = section['categoryIds']
        section_total = sum(len(all_duas.get(cid, [])) for cid in cat_ids)
        print(f"  {section['name']}: {len(cat_ids)} categories, {section_total} duas")


if __name__ == "__main__":
    main()
