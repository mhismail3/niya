#!/usr/bin/env python3
"""
build_dua_v2.py — Build a clean, comprehensive dua_all.json from multiple sources.

Sources:
  1. Current dua_all.json (English translations + transliterations, 280 entries)
  2. osamayy/azkar-db  (345 entries, Arabic + references + virtues, 135 categories)
  3. Seen-Arabic/Morning-And-Evening-Adhkar-DB (34 morning/evening, full EN quality)
  4. fitrahive/dua-dhikr (97 entries, source + benefits)
  5. rn0x/hisn_almuslim_json (134 chapters, Arabic + footnotes)

Strategy:
  - Use current data as English-translation base
  - Match azkar-db entries by Arabic text similarity to backfill references & virtues
  - Replace morning/evening adhkar with adhkar-db's superior versions
  - Enrich with fitrahive source/benefits
  - Clean formatting: strip (( )), normalize Arabic, separate instructions
  - Reorganize into thematic sections

Writes: ../Niya/Resources/Data/dua_all.json
"""

import json
import os
import re
import unicodedata

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "dua_all.json")

CURRENT_DATA = os.path.join(PROJECT_ROOT, "Niya", "Resources", "Data", "dua_all.json")
AZKAR_DB = "/tmp/dua-sources/azkar-db/azkar_obj.json"
ADHKAR_DB = "/tmp/dua-sources/adhkar-db/en.json"
FITRAHIVE_DIR = "/tmp/dua-sources/dua-dhikr/data"
HISN_JSON = "/tmp/dua-sources/hisn-json/hisn_almuslim.json"

# ---------------------------------------------------------------------------
# Arabic text normalization for matching
# ---------------------------------------------------------------------------

def normalize_arabic(text: str) -> str:
    """Normalize Arabic text for fuzzy matching."""
    if not text:
        return ""
    # Remove diacritics (tashkil)
    text = re.sub(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7-\u06E8\u06EA-\u06ED]', '', text)
    # Normalize alef variants
    text = re.sub(r'[إأآٱ]', 'ا', text)
    # Normalize taa marbuta
    text = text.replace('ة', 'ه')
    # Normalize yaa variants
    text = text.replace('ى', 'ي')
    # Remove tatweel
    text = text.replace('\u0640', '')
    # Remove (( )) [ ] and other brackets
    text = re.sub(r'[(\[\])﴿﴾«»]', '', text)
    # Collapse whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def arabic_fingerprint(text: str, words: int = 6) -> str:
    """Get first N words of normalized Arabic for matching."""
    norm = normalize_arabic(text)
    return ' '.join(norm.split()[:words])


def similarity_ratio(a: str, b: str) -> float:
    """Simple word-overlap similarity between two normalized Arabic strings."""
    wa = set(normalize_arabic(a).split())
    wb = set(normalize_arabic(b).split())
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / max(len(wa), len(wb))


# ---------------------------------------------------------------------------
# Formatting cleanup
# ---------------------------------------------------------------------------

def strip_wrapping_parens(text: str) -> str:
    """Remove parentheses only when they wrap the entire text.

    Handles cases like:
      "(O Allah, grant me health.)" → "O Allah, grant me health."
      "(First part.) (Second part.)" → "First part. Second part."
    Does NOT touch inline parens like "recite (7 times) daily".
    """
    s = text.strip()
    if not s.startswith('(') or not s.endswith(')'):
        return text
    # Find top-level paren groups. If the entire text is composed of
    # balanced (...) groups with only whitespace between them, strip
    # the outermost parens of each group.
    groups = []  # (start, end) indices of top-level groups
    i = 0
    while i < len(s):
        if s[i] == '(':
            depth = 1
            j = i + 1
            while j < len(s) and depth > 0:
                if s[j] == '(':
                    depth += 1
                elif s[j] == ')':
                    depth -= 1
                j += 1
            if depth != 0:
                return text  # unbalanced
            groups.append((i, j - 1))
            i = j
        elif s[i].isspace():
            i += 1
        else:
            return text  # non-paren content between groups → inline
    # Strip outer parens of each group
    parts = [s[start + 1 : end] for start, end in groups]
    return ' '.join(parts).strip()


def clean_arabic(text: str) -> str:
    """Clean Arabic text: remove all parens, normalize whitespace, strip BOM."""
    if not text:
        return ""
    # Strip BOM
    text = text.lstrip('\ufeff')
    # Remove all parentheses (single and double)
    text = text.replace('(', '').replace(')', '')
    # Remove square-bracket notes mixed in Arabic
    text = re.sub(r'\[.*?\]', '', text)
    # Clean up spacing around punctuation
    text = re.sub(r'\s*،\s*', '، ', text)
    text = re.sub(r'\s*\.\s*', '. ', text)
    # Collapse whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    # Remove leading/trailing periods and whitespace
    text = re.sub(r'^[\s.]+', '', text)
    text = re.sub(r'\.\s*$', '', text)
    return text


def clean_translation(text: str) -> str:
    """Clean English translation text."""
    if not text:
        return ""
    text = text.strip()
    # Remove leading/trailing quotes if wrapped
    if text.startswith("'") and text.endswith("'"):
        text = text[1:-1].strip()
    if text.startswith('"') and text.endswith('"'):
        text = text[1:-1].strip()
    # Strip text-wrapping parens but keep numbered verse markers
    text = strip_wrapping_parens(text)
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def clean_transliteration(text: str) -> str:
    """Clean transliteration text."""
    if not text:
        return None
    text = text.strip()
    if not text:
        return None
    # Strip text-wrapping parens but keep numbered verse markers
    text = strip_wrapping_parens(text)
    text = re.sub(r'\s+', ' ', text)
    return text


# ---------------------------------------------------------------------------
# Section/category organization
# ---------------------------------------------------------------------------

# Map Arabic category names → (english_name, section_id)
CATEGORY_MAP = {
    # Morning & Evening
    "أذكار الصباح": ("Morning Adhkar", "morning-evening"),
    "أذكار المساء": ("Evening Adhkar", "morning-evening"),

    # Sleep & Waking
    "أذكار النوم": ("Supplications Before Sleep", "sleep-waking"),
    "أذكار الاستيقاظ من النوم": ("Supplications Upon Waking", "sleep-waking"),
    "الدعاء إذا تقلب في الليل": ("When Tossing and Turning at Night", "sleep-waking"),
    "دعاء الفزع في النوم و من بلي بالوحشة": ("Upon Experiencing Fear or Loneliness in Sleep", "sleep-waking"),
    "ما يفعل من رأى الرؤيا أو الحلم في النوم": ("Upon Seeing a Good Dream or Nightmare", "sleep-waking"),
    "من تعار من الليل": ("Upon Waking in the Night", "sleep-waking"),

    # Prayer
    "دعاء الاستفتاح": ("Opening Supplication in Prayer", "prayer"),
    "دعاء الركوع": ("Supplication in Ruku (Bowing)", "prayer"),
    "دعاء الرفع من الركوع": ("Supplication Upon Rising from Ruku", "prayer"),
    "دعاء السجود": ("Supplication in Sujud (Prostration)", "prayer"),
    "دعاء الجلسة بين السجدتين": ("Supplication Between the Two Prostrations", "prayer"),
    "التشهد": ("The Tashahhud", "prayer"),
    "الصلاة على النبي بعد التشهد": ("Sending Prayers Upon the Prophet After Tashahhud", "prayer"),
    "الدعاء بعد التشهد الأخير قبل السلام": ("Supplication After the Final Tashahhud Before Salam", "prayer"),
    "الأذكار بعد السلام من الصلاة": ("Adhkar After Completing the Prayer", "prayer"),
    "الذكر عقب السلام من الوتر": ("Dhikr After Witr Prayer", "prayer"),
    "دعاء صلاة الاستخارة": ("Supplication for Istikhara Prayer", "prayer"),
    "دعاء سجود التلاوة": ("Supplication for Prostration of Recitation", "prayer"),
    "دعاء قنوت الوتر": ("Supplication for Qunut in Witr", "prayer"),
    "دعاء الوسوسة في الصلاة و القراءة": ("When Experiencing Doubt in Prayer", "prayer"),

    # Adhan & Mosque
    "أذكار الآذان": ("Supplications for the Adhan", "adhan-mosque"),
    "دعاء الذهاب إلى المسجد": ("Supplication When Going to the Mosque", "adhan-mosque"),
    "دعاء دخول المسجد": ("Supplication Upon Entering the Mosque", "adhan-mosque"),
    "دعاء الخروج من المسجد": ("Supplication Upon Leaving the Mosque", "adhan-mosque"),

    # Wudu & Dress
    "الذكر قبل الوضوء": ("Dhikr Before Wudu", "purification-dress"),
    "الذكر بعد الفراغ من الوضوء": ("Dhikr After Completing Wudu", "purification-dress"),
    "دعاء لبس الثوب": ("Supplication When Dressing", "purification-dress"),
    "دعاء لبس الثوب الجديد": ("Supplication When Wearing New Clothes", "purification-dress"),
    "ما يقول إذا وضع الثوب": ("What to Say When Removing Clothes", "purification-dress"),
    "دعاء دخول الخلاء": ("Supplication Upon Entering the Restroom", "purification-dress"),
    "دعاء الخروج من الخلاء": ("Supplication Upon Leaving the Restroom", "purification-dress"),

    # Home
    "الذكر عند دخول المنزل": ("Dhikr Upon Entering the Home", "daily-life"),
    "الذكر عند الخروج من المنزل": ("Dhikr Upon Leaving the Home", "daily-life"),

    # Food & Fasting
    "الدعاء قبل الطعام": ("Supplication Before Eating", "food-fasting"),
    "الدعاء عند الفراغ من الطعام": ("Supplication After Eating", "food-fasting"),
    "دعاء الضيف لصاحب الطعام": ("Guest's Supplication for the Host", "food-fasting"),
    "التعريض بالدعاء لطلب الطعام أو الشراب": ("Hinting at the Need for Food or Drink", "food-fasting"),
    "الدعاء إذا أفطر عند أهل بيت": ("Supplication When Breaking Fast at Someone's Home", "food-fasting"),
    "الدعاء عند إفطار الصائم": ("Supplication When Breaking the Fast", "food-fasting"),
    "دعاء الصائم إذا حضر الطعام ولم يفطر": ("Supplication of the Fasting Person When Presented with Food", "food-fasting"),
    "ما يقول الصائم إذا سابه أحد": ("What the Fasting Person Says When Insulted", "food-fasting"),
    "الدعاء عند رؤية باكورة الثمر": ("Supplication Upon Seeing the First Fruits", "food-fasting"),

    # Travel
    "دعاء الركوب": ("Supplication Upon Riding", "travel"),
    "دعاء السفر": ("Supplication for Travel", "travel"),
    "دعاء دخول القرية أو البلدة": ("Supplication Upon Entering a Town", "travel"),
    "دعاء دخول السوق": ("Supplication Upon Entering the Market", "travel"),
    "الدعاء إذا تعس المركوب": ("Supplication When the Mount Stumbles", "travel"),
    "دعاء المسافر للمقيم": ("Traveler's Supplication for the Resident", "travel"),
    "دعاء المقيم للمسافر": ("Resident's Supplication for the Traveler", "travel"),
    "التكبير و التسبيح في سير السفر": ("Takbir and Tasbih During Travel", "travel"),
    "دعاء المسافر إذا أسحر": ("Traveler's Supplication at Dawn", "travel"),
    "الدعاء إذا نزل مترلا في سفر أو غيره": ("Supplication When Stopping at a Place", "travel"),
    "ذكر الرجوع من السفر": ("Dhikr Upon Returning from Travel", "travel"),

    # Social & Etiquette
    "إفشاء السلام": ("Spreading the Greeting of Salam", "social"),
    "كيف يرد السلام على الكافر إذا سلم": ("Responding to a Non-Muslim's Greeting", "social"),
    "الدعاء للمتزوج": ("Supplication for the Newlywed", "social"),
    "دعاء المتزوج و شراء الدابة": ("Supplication of the Groom and Upon Purchase", "social"),
    "الدعاء قبل إتيان الزوجة": ("Supplication Before Intimacy", "social"),
    "ﺗﻬنئة المولود له وجوابه": ("Congratulating the New Parent", "social"),
    "ما يعوذ به الأولاد": ("Seeking Protection for Children", "social"),
    "الدعاء لمن صنع إليك معروفا": ("Supplication for One Who Does You a Favor", "social"),
    "الدعاء لمن قال إني أحبك في الله": ("Reply to 'I Love You for Allah's Sake'", "social"),
    "الدعاء لمن عرض عليك ماله": ("Supplication for One Who Offers You Wealth", "social"),
    "الدعاء لمن أقرض عند القضاء": ("Supplication for the Lender When Repaying", "social"),
    "الدعاء لمن قال بارك الله فيك": ("Reply to 'May Allah Bless You'", "social"),
    "الدعاء لمن قال غفر الله لك": ("Reply to 'May Allah Forgive You'", "social"),
    "ما يقول المسلم إذا مدح المسلم": ("What to Say When Praised", "social"),
    "ما يقول المسلم إذا زكي": ("What to Say When Commended", "social"),
    "دعاء العطاس": ("Supplication Upon Sneezing", "social"),
    "ما يقال للكافر إذا عطس فحمد الله": ("Reply to a Non-Muslim Who Sneezes", "social"),
    "ما يقال في اﻟﻤﺠلس": ("Supplication in a Gathering", "social"),
    "كفارة اﻟﻤﺠلس": ("Expiation for a Gathering", "social"),
    "دعاء التعجب والأمر السار": ("Supplication of Wonder and Good News", "social"),
    "ما يفعل من أتاه أمر يسره": ("What to Do Upon Receiving Good News", "social"),
    "ما يقول من أتاه أمر يسره أو يكرهه": ("What to Say for Good or Bad News", "social"),

    # Protection & Healing
    "الرقية الشرعية من القرآن الكريم": ("Ruqyah from the Quran", "protection"),
    "الرقية الشرعية من السنة النبوية": ("Ruqyah from the Sunnah", "protection"),
    "دعاء طرد الشيطان و وساوسه": ("Supplication to Ward Off Shaytan", "protection"),
    "دعاء من أصابه وسوسة في الإيمان": ("Supplication for Whispers of Doubt in Faith", "protection"),
    "ما يعصم الله به من الدجال": ("Protection from the Dajjal", "protection"),
    "ما يقول لرد كيد مردة الشياطين": ("Warding Off the Plots of Rebellious Devils", "protection"),
    "دعاء الخوف من الشرك": ("Supplication Against Shirk", "protection"),
    "ما يقول من أحس وجعا في جسده": ("Supplication for Bodily Pain", "protection"),
    "دعاء من خشي أن يصيب شيئا بعينه": ("Supplication to Avert the Evil Eye", "protection"),
    "ما يقال عند الفزع": ("Supplication Upon Experiencing Fear", "protection"),
    "دعاء نباح الكلب بالليل": ("Supplication Upon Hearing Dogs Barking at Night", "protection"),
    "الدعاء عند سماع صياح الديك ونهيق الحمار": ("Upon Hearing a Rooster Crow or Donkey Bray", "protection"),

    # Hardship & Distress
    "دعاء الكرب": ("Supplication in Times of Distress", "hardship"),
    "دعاء الهم والحزن": ("Supplication for Anxiety and Grief", "hardship"),
    "دعاء قضاء الدين": ("Supplication for Repaying Debt", "hardship"),
    "دعاء من استصعب عليه أمر": ("Supplication for a Difficult Matter", "hardship"),
    "الدعاء حينما يقع ما لا يرضاه أو غلب على أمره": ("When Something Unpleasant Happens", "hardship"),
    "ما يقول ويفعل من أذنب ذنبا": ("Supplication After Committing a Sin", "hardship"),
    "دعاء الغضب": ("Supplication When Feeling Angry", "hardship"),
    "دعاء من رأى مبتلى": ("Supplication Upon Seeing Someone Afflicted", "hardship"),
    "دعاء لقاء العدو و ذي السلطان": ("Supplication When Facing an Enemy or Authority", "hardship"),
    "الدعاء على العدو": ("Supplication Against an Oppressor", "hardship"),
    "ما يقول من خاف قوما": ("Supplication When Fearing a People", "hardship"),
    "دعاء كراهية الطيرة": ("Supplication Against Bad Omens", "hardship"),
    "الدعاء لمن سببته": ("Supplication for One You Have Wronged", "hardship"),

    # Illness & Death
    "فضل عيادة المريض": ("Virtue of Visiting the Sick", "illness-death"),
    "الدعاء للمريض في عيادته": ("Supplication When Visiting the Sick", "illness-death"),
    "دعاء المريض الذي يئس من حياته": ("Supplication of the Terminally Ill", "illness-death"),
    "تلقين المحتضر": ("Prompting the Dying Person", "illness-death"),
    "دعاء من أصيب بمصيبة": ("Supplication Upon a Calamity", "illness-death"),
    "الدعاء عند إغماض الميت": ("Supplication When Closing the Eyes of the Deceased", "illness-death"),
    "الدعاء للميت في الصلاة عليه": ("Supplication in the Funeral Prayer", "illness-death"),
    "الدعاء للفرط في الصلاة عليه": ("Supplication for a Deceased Child", "illness-death"),
    "دعاء التعزية": ("Supplication of Condolence", "illness-death"),
    "الدعاء عند إدخال الميت القبر": ("Supplication When Placing in the Grave", "illness-death"),
    "الدعاء بعد دفن الميت": ("Supplication After Burial", "illness-death"),
    "دعاء زيارة القبور": ("Supplication When Visiting Graves", "illness-death"),

    # Weather & Nature
    "دعاء الرعد": ("Supplication Upon Hearing Thunder", "weather"),
    "الدعاء إذا نزل المطر": ("Supplication When It Rains", "weather"),
    "الذكر بعد نزول المطر": ("Dhikr After Rain", "weather"),
    "من أدعية الاستسقاء": ("Supplications for Rain (Istisqa)", "weather"),
    "من أدعية الاستصحاء": ("Supplication to Stop Rain", "weather"),
    "دعاء الريح": ("Supplication Upon Strong Wind", "weather"),
    "دعاء رؤية الهلال": ("Supplication Upon Seeing the New Moon", "weather"),

    # Hajj & Umrah
    "كيف يلبي المحرم في الحج أو العمرة ؟": ("The Talbiyah for Hajj and Umrah", "hajj-umrah"),
    "التكبير إذا أتى الركن الأسود": ("Takbir at the Black Stone", "hajj-umrah"),
    "الدعاء بين الركن اليماني والحجر الأسود": ("Supplication Between Rukn Yamani and the Black Stone", "hajj-umrah"),
    "دعاء الوقوف على الصفا والمروة": ("Supplication at Safa and Marwa", "hajj-umrah"),
    "الدعاء يوم عرفة": ("Supplication on the Day of Arafah", "hajj-umrah"),
    "الذكر عند المشعر الحرام": ("Dhikr at al-Mash'ar al-Haram", "hajj-umrah"),
    "التكبير عند رمي الجمار مع كل حصاة": ("Takbir When Stoning the Jamarat", "hajj-umrah"),

    # Remembrance & Forgiveness
    "التسبيح، التحميد، التهليل، التكبير": ("Tasbih, Tahmid, Tahlil, and Takbir", "remembrance"),
    "الاستغفار و التوبة": ("Istighfar and Repentance", "remembrance"),
    "فضل الصلاة على النبي صلى الله عليه و سلم": ("Virtue of Sending Salawat Upon the Prophet", "remembrance"),
    "أماكن وأوقات إجابة الدعاء ": ("Times and Places When Dua is Answered", "remembrance"),
    "كيف كان النبي يسبح؟": ("How the Prophet Would Make Tasbih", "remembrance"),
    "من أنواع الخير والآداب الجامعة": ("Comprehensive Good Deeds and Manners", "remembrance"),
    "ما يقول عند الذبح أو النحر": ("Supplication When Slaughtering", "remembrance"),
}

SECTION_NAMES = {
    "morning-evening": "Morning & Evening",
    "sleep-waking": "Sleep & Waking",
    "prayer": "Prayer",
    "adhan-mosque": "Adhan & Mosque",
    "purification-dress": "Purification & Dress",
    "daily-life": "Home & Daily Life",
    "food-fasting": "Food & Fasting",
    "travel": "Travel",
    "social": "Social & Etiquette",
    "protection": "Protection & Healing",
    "hardship": "Hardship & Distress",
    "illness-death": "Illness & Death",
    "weather": "Weather & Nature",
    "hajj-umrah": "Hajj & Umrah",
    "remembrance": "Remembrance & Forgiveness",
}

SECTION_ORDER = [
    "morning-evening", "sleep-waking", "prayer", "adhan-mosque",
    "purification-dress", "daily-life", "food-fasting", "travel",
    "social", "protection", "hardship", "illness-death",
    "weather", "hajj-umrah", "remembrance",
]


# ---------------------------------------------------------------------------
# Load sources
# ---------------------------------------------------------------------------

def load_current() -> dict:
    """Load existing dua_all.json."""
    with open(CURRENT_DATA, encoding='utf-8') as f:
        return json.load(f)


def load_azkar_db() -> list[dict]:
    """Load osamayy/azkar-db."""
    with open(AZKAR_DB, encoding='utf-8') as f:
        return json.load(f)


def load_adhkar_db() -> list[dict]:
    """Load Seen-Arabic morning/evening adhkar."""
    with open(ADHKAR_DB, encoding='utf-8') as f:
        return json.load(f)


def load_fitrahive() -> list[dict]:
    """Load all fitrahive English data files."""
    results = []
    for root, _, files in os.walk(FITRAHIVE_DIR):
        for fname in files:
            if fname == 'en.json':
                fp = os.path.join(root, fname)
                with open(fp, encoding='utf-8') as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        results.extend(data)
    return results


def load_hisn_json() -> dict:
    """Load rn0x hisn al-muslim JSON."""
    with open(HISN_JSON, encoding='utf-8') as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Build index of current data by Arabic fingerprint
# ---------------------------------------------------------------------------

def build_current_index(current: dict) -> dict:
    """Build fingerprint → dua mapping from current data."""
    index = {}
    for cat_id, duas in current.get('duas', {}).items():
        for dua in duas:
            fp = arabic_fingerprint(dua['arabic'])
            if fp:
                index[fp] = dua
    return index


def build_azkar_index(azkar: list[dict]) -> dict:
    """Build fingerprint → azkar entry mapping."""
    index = {}
    for entry in azkar:
        fp = arabic_fingerprint(entry.get('zekr', ''))
        if fp:
            index[fp] = entry
    return index


def build_fitrahive_index(fitrahive: list[dict]) -> dict:
    """Build fingerprint → fitrahive entry mapping."""
    index = {}
    for entry in fitrahive:
        fp = arabic_fingerprint(entry.get('arabic', ''))
        if fp:
            index[fp] = entry
    return index


# ---------------------------------------------------------------------------
# Match and merge entries
# ---------------------------------------------------------------------------

def find_best_match(fp: str, index: dict, threshold: float = 0.5) -> dict | None:
    """Find best matching entry in index by fingerprint similarity."""
    if fp in index:
        return index[fp]
    # Try partial matches
    best_score = 0
    best_entry = None
    for key, entry in index.items():
        score = similarity_ratio(fp, key)
        if score > best_score and score >= threshold:
            best_score = score
            best_entry = entry
    return best_entry


def merge_entry(
    arabic_cat: str,
    arabic_text: str,
    current_match: dict | None,
    azkar_match: dict | None,
    fitrahive_match: dict | None,
    repeat_count: int | None,
) -> dict:
    """Merge a single dua entry from multiple sources."""
    entry = {}

    # Arabic text: prefer current (already cleaned in prior runs), clean it further
    if current_match:
        entry['arabic'] = clean_arabic(current_match.get('arabic', arabic_text))
    else:
        entry['arabic'] = clean_arabic(arabic_text)

    # Translation: prefer current
    if current_match and current_match.get('translation', '').strip():
        entry['translation'] = clean_translation(current_match['translation'])
    elif fitrahive_match and fitrahive_match.get('translation', '').strip():
        entry['translation'] = clean_translation(fitrahive_match['translation'])
    else:
        entry['translation'] = ""

    # Transliteration
    if current_match and current_match.get('transliteration'):
        entry['transliteration'] = clean_transliteration(current_match['transliteration'])
    elif fitrahive_match and fitrahive_match.get('latin'):
        entry['transliteration'] = clean_transliteration(fitrahive_match['latin'])

    # Repeat count
    if repeat_count and repeat_count > 0:
        entry['repeat'] = repeat_count
    elif current_match and current_match.get('repeat'):
        entry['repeat'] = current_match['repeat']

    # Reference/source: prefer azkar-db (most citations), then fitrahive, then current
    ref = None
    if azkar_match and azkar_match.get('reference', '').strip():
        ref = azkar_match['reference'].strip()
    if not ref and fitrahive_match and (fitrahive_match.get('source') or '').strip():
        ref = fitrahive_match['source'].strip()
    if not ref and current_match and (current_match.get('source') or '').strip():
        ref = current_match['source'].strip()
    if ref:
        entry['source'] = ref

    # Benefits/virtues: prefer azkar-db description, then fitrahive, then current
    benefits = None
    if azkar_match and azkar_match.get('description', '').strip():
        benefits = azkar_match['description'].strip()
    if not benefits and fitrahive_match:
        b = fitrahive_match.get('benefits') or fitrahive_match.get('fawaid')
        if b and str(b).strip():
            benefits = str(b).strip()
    if not benefits and current_match and current_match.get('benefits', '').strip():
        benefits = current_match['benefits'].strip()
    if benefits:
        entry['benefits'] = benefits

    return entry


# ---------------------------------------------------------------------------
# Build morning/evening section from adhkar-db
# ---------------------------------------------------------------------------

def build_morning_evening(adhkar: list[dict]) -> list[dict]:
    """Build morning/evening adhkar from the Seen-Arabic dataset (highest quality)."""
    entries = []
    for item in adhkar:
        entry = {
            'arabic': clean_arabic(item.get('content', '')),
            'translation': clean_translation(item.get('translation', '')),
        }
        translit = clean_transliteration(item.get('transliteration'))
        if translit:
            entry['transliteration'] = translit

        count = item.get('count', 1)
        if count and count > 1:
            entry['repeat'] = count

        source = item.get('source', '').strip()
        if source:
            entry['source'] = source

        fadl = item.get('fadl', '').strip()
        if fadl:
            entry['benefits'] = fadl

        entries.append(entry)
    return entries


# ---------------------------------------------------------------------------
# Main build
# ---------------------------------------------------------------------------

def build():
    print("Loading sources...")
    current = load_current()
    azkar = load_azkar_db()
    adhkar = load_adhkar_db()
    fitrahive = load_fitrahive()

    print(f"  Current: {sum(len(v) for v in current['duas'].values())} duas")
    print(f"  Azkar-DB: {len(azkar)} entries")
    print(f"  Adhkar-DB: {len(adhkar)} entries")
    print(f"  Fitrahive: {len(fitrahive)} entries")

    # Build indexes
    current_index = build_current_index(current)
    fitrahive_index = build_fitrahive_index(fitrahive)
    azkar_index = build_azkar_index(azkar)

    print(f"  Current index: {len(current_index)} fingerprints")
    print(f"  Fitrahive index: {len(fitrahive_index)} fingerprints")
    print(f"  Azkar index: {len(azkar_index)} fingerprints")

    # Group azkar-db by Arabic category
    azkar_by_cat: dict[str, list[dict]] = {}
    for entry in azkar:
        cat = entry['category']
        if cat not in azkar_by_cat:
            azkar_by_cat[cat] = []
        azkar_by_cat[cat].append(entry)

    # Build morning/evening from adhkar-db (separate, higher quality)
    morning_adhkar = build_morning_evening([a for a in adhkar if a.get('type') in (0, 1)])
    evening_adhkar = build_morning_evening([a for a in adhkar if a.get('type') in (0, 2)])

    # Build all categories and duas
    categories = []
    duas_by_cat = {}
    cat_id = 1
    global_dua_id = 1  # globally unique dua ID counter

    # Track section → category IDs
    section_cats: dict[str, list[int]] = {s: [] for s in SECTION_ORDER}

    # Morning/evening from adhkar-db
    # Morning
    categories.append({
        'id': cat_id,
        'name': 'Morning Adhkar',
        'sectionId': 'morning-evening',
        'totalDuas': len(morning_adhkar),
    })
    section_cats['morning-evening'].append(cat_id)
    for i, dua in enumerate(morning_adhkar, 1):
        dua['id'] = global_dua_id
        dua['number'] = i
        global_dua_id += 1
    duas_by_cat[cat_id] = morning_adhkar
    cat_id += 1

    # Evening
    categories.append({
        'id': cat_id,
        'name': 'Evening Adhkar',
        'sectionId': 'morning-evening',
        'totalDuas': len(evening_adhkar),
    })
    section_cats['morning-evening'].append(cat_id)
    for i, dua in enumerate(evening_adhkar, 1):
        dua['id'] = global_dua_id
        dua['number'] = i
        global_dua_id += 1
    duas_by_cat[cat_id] = evening_adhkar
    cat_id += 1

    # Process remaining azkar-db categories (skip morning/evening — already handled)
    skip_cats = {"أذكار الصباح", "أذكار المساء", "المقدمة", "فضل الذكر"}

    # Also skip unmapped categories
    unmapped = []

    for arabic_cat, azkar_entries in sorted(azkar_by_cat.items(), key=lambda x: x[0]):
        if arabic_cat in skip_cats:
            continue

        mapping = CATEGORY_MAP.get(arabic_cat)
        if not mapping:
            unmapped.append(arabic_cat)
            continue

        en_name, section_id = mapping

        # Build duas for this category
        cat_duas = []
        for azkar_entry in azkar_entries:
            arabic = azkar_entry.get('zekr', '')
            if not arabic.strip():
                continue

            fp = arabic_fingerprint(arabic)
            current_match = find_best_match(fp, current_index)
            fitrahive_match = find_best_match(fp, fitrahive_index)

            count_raw = azkar_entry.get('count', '')
            try:
                repeat = int(count_raw) if count_raw else None
            except (ValueError, TypeError):
                repeat = None

            merged = merge_entry(
                arabic_cat, arabic,
                current_match, azkar_entry, fitrahive_match,
                repeat,
            )

            # Skip entries with no English translation (Arabic-only)
            if not merged.get('translation'):
                continue

            cat_duas.append(merged)

        if not cat_duas:
            continue

        categories.append({
            'id': cat_id,
            'name': en_name,
            'sectionId': section_id,
            'totalDuas': len(cat_duas),
        })
        section_cats[section_id].append(cat_id)

        for i, dua in enumerate(cat_duas, 1):
            dua['id'] = global_dua_id
            dua['number'] = i
            global_dua_id += 1
        duas_by_cat[cat_id] = cat_duas
        cat_id += 1

    # Now check: are there current duas in categories NOT covered by azkar-db?
    # Track existing category names to avoid duplicates
    existing_cat_names = {c['name'] for c in categories}

    current_cats_used = set()
    for cat_data in current.get('categories', []):
        cat_name = cat_data['name']
        cat_key = str(cat_data['id'])
        cur_duas = current['duas'].get(cat_key, [])
        if not cur_duas:
            continue

        # Skip if a category with this name already exists
        if cat_name in existing_cat_names:
            continue

        # Check if any dua from this category was already matched
        matched = False
        for dua in cur_duas:
            fp = arabic_fingerprint(dua['arabic'])
            if fp in azkar_index:
                matched = True
                break
        if matched:
            continue

        # This current category wasn't matched — check if it maps to a known section
        # Try to find section by current section mapping
        cur_section = cat_data.get('sectionId', '')
        section_map = {
            'morning-evening-sleep': 'sleep-waking',
            'daily-routine': 'daily-life',
            'prayer-mosque': 'prayer',
            'food-fasting': 'food-fasting',
            'travel': 'travel',
            'social-etiquette': 'social',
            'hardship-protection': 'hardship',
            'illness-death': 'illness-death',
            'weather-seasons': 'weather',
            'hajj-umrah': 'hajj-umrah',
            'remembrance-forgiveness': 'remembrance',
        }
        target_section = section_map.get(cur_section, '')

        if not target_section:
            continue

        # Add these unmatched current duas as an additional category
        cat_duas = []
        for dua in cur_duas:
            if not dua.get('translation', '').strip():
                continue
            entry = {
                'arabic': clean_arabic(dua['arabic']),
                'translation': clean_translation(dua['translation']),
            }
            if dua.get('transliteration'):
                entry['transliteration'] = clean_transliteration(dua['transliteration'])
            if dua.get('repeat') and dua['repeat'] > 1:
                entry['repeat'] = dua['repeat']
            if dua.get('source'):
                entry['source'] = dua['source']
            if dua.get('benefits'):
                entry['benefits'] = dua['benefits']

            # Try to enrich with azkar/fitrahive
            fp = arabic_fingerprint(dua['arabic'])
            azkar_match = find_best_match(fp, azkar_index, threshold=0.6)
            if azkar_match:
                if not entry.get('source') and azkar_match.get('reference', '').strip():
                    entry['source'] = azkar_match['reference'].strip()
                if not entry.get('benefits') and azkar_match.get('description', '').strip():
                    entry['benefits'] = azkar_match['description'].strip()

            cat_duas.append(entry)

        if cat_duas:
            categories.append({
                'id': cat_id,
                'name': cat_name,
                'sectionId': target_section,
                'totalDuas': len(cat_duas),
            })
            section_cats[target_section].append(cat_id)
            for i, dua in enumerate(cat_duas, 1):
                dua['id'] = global_dua_id
                dua['number'] = i
                global_dua_id += 1
            duas_by_cat[cat_id] = cat_duas
            cat_id += 1

    # Build sections
    sections = []
    for section_id in SECTION_ORDER:
        cat_ids = section_cats.get(section_id, [])
        if cat_ids:
            sections.append({
                'id': section_id,
                'name': SECTION_NAMES[section_id],
                'categoryIds': cat_ids,
            })

    # Build output
    output = {
        'sections': sections,
        'categories': categories,
        'duas': {str(k): v for k, v in duas_by_cat.items()},
    }

    # Stats
    total_duas = sum(len(v) for v in duas_by_cat.values())
    has_translit = sum(1 for v in duas_by_cat.values() for d in v if d.get('transliteration'))
    has_source = sum(1 for v in duas_by_cat.values() for d in v if d.get('source'))
    has_benefits = sum(1 for v in duas_by_cat.values() for d in v if d.get('benefits'))
    has_repeat = sum(1 for v in duas_by_cat.values() for d in v if d.get('repeat'))
    no_translation = sum(1 for v in duas_by_cat.values() for d in v if not d.get('translation'))

    print(f"\n=== OUTPUT ===")
    print(f"Sections: {len(sections)}")
    print(f"Categories: {len(categories)}")
    print(f"Total duas: {total_duas}")
    print(f"  With transliteration: {has_translit}/{total_duas}")
    print(f"  With source/reference: {has_source}/{total_duas}")
    print(f"  With benefits/virtues: {has_benefits}/{total_duas}")
    print(f"  With repeat count: {has_repeat}/{total_duas}")
    print(f"  Missing translation: {no_translation}/{total_duas}")

    if unmapped:
        print(f"\nUnmapped azkar-db categories ({len(unmapped)}):")
        for c in unmapped:
            print(f"  {c}")

    # Write output
    with open(OUTPUT, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    print(f"\nWritten: {OUTPUT}")
    print(f"Size: {os.path.getsize(OUTPUT) / 1024:.1f} KB")


if __name__ == '__main__':
    build()
