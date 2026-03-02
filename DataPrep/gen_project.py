#!/usr/bin/env python3
"""
gen_project.py — regenerate Niya.xcodeproj/project.pbxproj
"""

import uuid
import os

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def new_id():
    """Return a 24-character uppercase hex string (Xcode-style UUID)."""
    return uuid.uuid4().hex[:24].upper()


def pbx_string(s):
    """Quote a string for pbxproj if it contains special characters."""
    safe = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._/-")
    if all(c in safe for c in s):
        return s
    escaped = s.replace('"', '\\"')
    return f'"{escaped}"'


# ---------------------------------------------------------------------------
# Project data
# ---------------------------------------------------------------------------

PROJECT_ROOT = "/Users/moose/Downloads/projects/niya"
PBXPROJ_PATH = os.path.join(PROJECT_ROOT, "Niya.xcodeproj", "project.pbxproj")

BUNDLE_ID    = "com.niya.mobile"
PRODUCT_NAME = "Niya"
DEPLOYMENT   = "17.0"
SWIFT_VER    = "6.2"

# Swift source files — paths relative to project root
SWIFT_FILES = [
    "Niya/NiyaApp.swift",
    "Niya/ContentView.swift",
    # Models
    "Niya/Models/QuranScript.swift",
    "Niya/Models/Surah.swift",
    "Niya/Models/Verse.swift",
    "Niya/Models/AudioDownload.swift",
    "Niya/Models/ReadingPosition.swift",
    "Niya/Models/RecentSearch.swift",
    "Niya/Models/HadithCollection.swift",
    "Niya/Models/HadithChapter.swift",
    "Niya/Models/Hadith.swift",
    "Niya/Models/HadithGrade.swift",
    "Niya/Models/HadithBookmark.swift",
    "Niya/Models/QuranBookmark.swift",
    "Niya/Models/DuaSection.swift",
    "Niya/Models/DuaCategory.swift",
    "Niya/Models/Dua.swift",
    "Niya/Models/DuaBookmark.swift",
    "Niya/Models/RecentHadith.swift",
    "Niya/Models/RecentDua.swift",
    "Niya/Models/TajweedRule.swift",
    "Niya/Models/TajweedAnnotation.swift",
    "Niya/Models/TajweedVerse.swift",
    "Niya/Models/Word.swift",
    "Niya/Models/Reciter.swift",
    "Niya/Models/TranslationEdition.swift",
    "Niya/Models/TafsirEdition.swift",
    "Niya/Models/UserLocation.swift",
    "Niya/Models/CalculationMethod.swift",
    "Niya/Models/PrayerTime.swift",
    # Services
    "Niya/Services/QuranDataService.swift",
    "Niya/Services/AudioService.swift",
    "Niya/Services/DownloadStore.swift",
    "Niya/Services/ReadingPositionStore.swift",
    "Niya/Services/RecentSearchStore.swift",
    "Niya/Services/HadithDataService.swift",
    "Niya/Services/HadithBookmarkStore.swift",
    "Niya/Services/QuranBookmarkStore.swift",
    "Niya/Services/DuaDataService.swift",
    "Niya/Services/DuaBookmarkStore.swift",
    "Niya/Services/RecentHadithStore.swift",
    "Niya/Services/RecentDuaStore.swift",
    "Niya/Services/TajweedService.swift",
    "Niya/Services/WordDataService.swift",
    "Niya/Services/TafsirService.swift",
    "Niya/Services/PrayerTimeCalculator.swift",
    "Niya/Services/LocationService.swift",
    "Niya/Services/PrayerTimeService.swift",
    # ViewModels
    "Niya/ViewModels/SurahListViewModel.swift",
    "Niya/ViewModels/ReaderViewModel.swift",
    "Niya/ViewModels/AudioPlayerViewModel.swift",
    "Niya/ViewModels/FollowAlongViewModel.swift",
    # Views/SurahList
    "Niya/Views/SurahList/SurahListView.swift",
    "Niya/Views/SurahList/SurahRowView.swift",
    "Niya/Views/SurahList/SurahSearchView.swift",
    # Views/Reader
    "Niya/Views/Reader/ReaderContainerView.swift",
    "Niya/Views/Reader/ScrollReaderView.swift",
    "Niya/Views/Reader/PageReaderView.swift",
    "Niya/Views/Reader/VerseRowView.swift",
    "Niya/Views/Reader/MushaPageView.swift",
    "Niya/Views/Reader/ReaderSettingsSheet.swift",
    "Niya/Views/Reader/TajweedTextView.swift",
    "Niya/Views/Reader/FollowAlongVerseView.swift",
    "Niya/Views/Reader/WordView.swift",
    "Niya/Views/Reader/VerseCellView.swift",
    "Niya/Views/Reader/TranslationPickerView.swift",
    "Niya/Views/Reader/TafsirSheetView.swift",
    # Views/Audio
    "Niya/Views/Audio/AudioPlayerBar.swift",
    # Views/Home
    "Niya/Views/Home/HomeView.swift",
    "Niya/Views/Home/ContinueReadingCard.swift",
    "Niya/Views/Home/RecentHadithCard.swift",
    "Niya/Views/Home/RecentDuaCard.swift",
    # Views/Shared
    "Niya/Views/BookmarksView.swift",
    # Views/Settings
    "Niya/Views/Settings/SettingsView.swift",
    # Views/Hadith
    "Niya/Views/Hadith/HadithTabView.swift",
    "Niya/Views/Hadith/HadithCollectionCard.swift",
    "Niya/Views/Hadith/HadithCollectionView.swift",
    "Niya/Views/Hadith/HadithChapterRow.swift",
    "Niya/Views/Hadith/HadithChapterView.swift",
    "Niya/Views/Hadith/HadithRowView.swift",
    "Niya/Views/Hadith/HadithDetailView.swift",
    "Niya/Views/Hadith/HadithBookmarksView.swift",
    "Niya/Views/Hadith/HadithSearchResultRow.swift",
    # Views/Salah
    "Niya/Views/Salah/SalahSheetView.swift",
    "Niya/Views/Salah/QiblahCompassView.swift",
    "Niya/Views/Salah/PrayerTimesListView.swift",
    "Niya/Views/Salah/LocationPickerView.swift",
    # Views/Dua
    "Niya/Views/Dua/DuaTabView.swift",
    "Niya/Views/Dua/DuaSectionView.swift",
    "Niya/Views/Dua/DuaRowView.swift",
    "Niya/Views/Dua/DuaDetailView.swift",
    "Niya/Views/Dua/DuaSearchResultRow.swift",
    # Onboarding
    "Niya/Onboarding/ReaderTips.swift",
    # Design
    "Niya/Design/NiyaColors.swift",
    "Niya/Design/NiyaFonts.swift",
    "Niya/Design/NiyaTheme.swift",
    "Niya/Design/NiyaExtensions.swift",
    "Niya/Design/NiyaToolbar.swift",
    "Niya/Design/FlowLayout.swift",
    "Niya/Design/ViewCompat.swift",
]

# Resource files — paths relative to project root
RESOURCE_FILES = [
    "Niya/Resources/Data/surahs.json",
    "Niya/Resources/Data/verses_hafs.json",
    "Niya/Resources/Data/verses_indopak.json",
    "Niya/Resources/Data/hadith_collections.json",
    "Niya/Resources/Data/hadith_bukhari.json",
    "Niya/Resources/Data/hadith_muslim.json",
    "Niya/Resources/Data/hadith_abudawud.json",
    "Niya/Resources/Data/hadith_tirmidhi.json",
    "Niya/Resources/Data/hadith_nasai.json",
    "Niya/Resources/Data/hadith_ibnmajah.json",
    "Niya/Resources/Data/hadith_malik.json",
    "Niya/Resources/Data/hadith_ahmed.json",
    "Niya/Resources/Data/hadith_darimi.json",
    "Niya/Resources/Data/hadith_nawawi.json",
    "Niya/Resources/Data/hadith_qudsi.json",
    "Niya/Resources/Data/hadith_dehlawi.json",
    "Niya/Resources/Data/hadith_aladab.json",
    "Niya/Resources/Data/hadith_bulugh.json",
    "Niya/Resources/Data/hadith_mishkat.json",
    "Niya/Resources/Data/hadith_riyad.json",
    "Niya/Resources/Data/hadith_shamail.json",
    "Niya/Resources/Data/dua_all.json",
    "Niya/Resources/Data/word_data.json",
    "Niya/Resources/Data/noreen_word_data.json",
    "Niya/Resources/Data/translations_index.json",
    "Niya/Resources/Data/translation_en_sahih.json",
    "Niya/Resources/Data/translation_en_clearquran.json",
    "Niya/Resources/Data/translation_en_hilali.json",
    "Niya/Resources/Data/translation_fr_hamidullah.json",
    "Niya/Resources/Data/translation_es_cortes.json",
    "Niya/Resources/Data/translation_tr_diyanet.json",
    "Niya/Resources/Data/translation_ur_maududi.json",
    "Niya/Resources/Data/translation_id_indonesian.json",
    "Niya/Resources/Data/translation_bn_bengali.json",
    "Niya/Resources/Data/translation_de_bubenheim.json",
    "Niya/Resources/Data/translation_ru_kuliev.json",
    "Niya/Resources/Data/translation_ms_basmeih.json",
    "Niya/Resources/Data/translation_zh_jian.json",
    "Niya/Resources/Fonts/KFGQPC Uthmanic Script HAFS Regular.otf",
    "Niya/Resources/Fonts/ScheherazadeNew-Regular.ttf",
    "Niya/Resources/Fonts/NotoNaskhArabic-Regular.ttf",
]

# Test files
TEST_FILES = [
    "NiyaTests/ReadingPositionModelTests.swift",
    "NiyaTests/ReadingPositionStoreTests.swift",
    "NiyaTests/ContinueReadingCardTests.swift",
    "NiyaTests/ReaderViewModelTests.swift",
    "NiyaTests/HadithModelTests.swift",
    "NiyaTests/HadithDataServiceTests.swift",
    "NiyaTests/HadithBookmarkStoreTests.swift",
    "NiyaTests/WordModelTests.swift",
    "NiyaTests/WordDataServiceTests.swift",
    "NiyaTests/AudioServiceTests.swift",
    "NiyaTests/FollowAlongViewModelTests.swift",
    "NiyaTests/WordDataIntegrityTests.swift",
    "NiyaTests/TajweedServiceTests.swift",
    "NiyaTests/ReciterTests.swift",
    "NiyaTests/AudioPlayerViewModelTests.swift",
    "NiyaTests/HadithDataIntegrityTests.swift",
    "NiyaTests/TranslationTests.swift",
    "NiyaTests/TafsirEditionTests.swift",
    "NiyaTests/TafsirServiceTests.swift",
    "NiyaTests/TafsirSheetViewTests.swift",
    "NiyaTests/ViewCompatTests.swift",
    "NiyaTests/UserLocationTests.swift",
    "NiyaTests/CalculationMethodTests.swift",
    "NiyaTests/PrayerTimeModelTests.swift",
    "NiyaTests/PrayerTimeCalculatorTests.swift",
    "NiyaTests/QiblahBearingTests.swift",
]

# Assets catalog — treated specially
ASSETS_PATH = "Niya/Resources/Assets.xcassets"

# System frameworks to link
FRAMEWORKS = [
    ("SwiftData.framework",    "SwiftData"),
    ("AVFoundation.framework", "AVFoundation"),
]

# ---------------------------------------------------------------------------
# Allocate all UUIDs up-front so they can be referenced freely
# ---------------------------------------------------------------------------

# Top-level structural objects
ID_PROJECT          = new_id()
ID_TARGET           = new_id()
ID_TEST_TARGET      = new_id()
ID_PRODUCTS_GROUP   = new_id()
ID_MAIN_GROUP       = new_id()
ID_NIYA_GROUP       = new_id()   # "Niya" source group
ID_TESTS_GROUP      = new_id()   # "NiyaTests" source group

# Build phases
ID_SOURCES_PHASE    = new_id()
ID_RESOURCES_PHASE  = new_id()
ID_FRAMEWORKS_PHASE = new_id()
ID_TEST_SOURCES_PHASE = new_id()
ID_TEST_FRAMEWORKS_PHASE = new_id()

# Build configurations
ID_DEBUG_PROJECT    = new_id()
ID_RELEASE_PROJECT  = new_id()
ID_DEBUG_TARGET     = new_id()
ID_RELEASE_TARGET   = new_id()
ID_DEBUG_TEST_TARGET  = new_id()
ID_RELEASE_TEST_TARGET = new_id()
ID_CFGLIST_PROJECT  = new_id()
ID_CFGLIST_TARGET   = new_id()
ID_CFGLIST_TEST_TARGET = new_id()

# Product file reference
ID_PRODUCT_REF      = new_id()
ID_TEST_PRODUCT_REF = new_id()

# Target dependency
ID_TARGET_DEPENDENCY = new_id()
ID_CONTAINER_ITEM_PROXY = new_id()

# Sub-groups inside Niya/
SUBGROUP_IDS = {
    "Models":             new_id(),
    "Services":           new_id(),
    "ViewModels":         new_id(),
    "Views":              new_id(),
    "Views/SurahList":    new_id(),
    "Views/Reader":       new_id(),
    "Views/Audio":        new_id(),
    "Views/Home":         new_id(),
    "Views/Settings":     new_id(),
    "Views/Hadith":       new_id(),
    "Views/Dua":          new_id(),
    "Views/Salah":        new_id(),
    "Onboarding":         new_id(),
    "Design":             new_id(),
    "Resources":          new_id(),
    "Resources/Data":     new_id(),
    "Resources/Fonts":    new_id(),
}

# Per-file IDs
swift_file_ids   = {p: new_id() for p in SWIFT_FILES}
swift_build_ids  = {p: new_id() for p in SWIFT_FILES}

resource_file_ids  = {p: new_id() for p in RESOURCE_FILES}
resource_build_ids = {p: new_id() for p in RESOURCE_FILES}

test_file_ids  = {p: new_id() for p in TEST_FILES}
test_build_ids = {p: new_id() for p in TEST_FILES}

# Assets catalog
ID_ASSETS_FILE  = new_id()
ID_ASSETS_BUILD = new_id()

# Frameworks
fw_file_ids  = {name: new_id() for name, _ in FRAMEWORKS}
fw_build_ids = {name: new_id() for name, _ in FRAMEWORKS}

# Frameworks group inside main group
ID_FRAMEWORKS_GROUP = new_id()

# Info.plist file reference (not in any build phase)
ID_INFOPLIST = new_id()

# ---------------------------------------------------------------------------
# Build the pbxproj sections
# ---------------------------------------------------------------------------

def file_type_for(path):
    ext = os.path.splitext(path)[1].lower()
    return {
        ".swift": "sourcecode.swift",
        ".json":  "text.json",
        ".ttf":   "file.font",
        ".otf":   "file.font",
        ".plist": "text.plist.xml",
        ".m":     "sourcecode.c.objc",
    }.get(ext, "file")


def basename(path):
    return os.path.basename(path)


def indent(n, text):
    prefix = "\t" * n
    return "\n".join(prefix + line if line.strip() else line
                     for line in text.splitlines())


# ---------------------------------------------------------------------------
# Section builders
# ---------------------------------------------------------------------------

def section_pbx_build_file():
    lines = ["/* Begin PBXBuildFile section */"]

    for path in SWIFT_FILES:
        bid = swift_build_ids[path]
        fid = swift_file_ids[path]
        name = basename(path)
        lines.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")

    for path in RESOURCE_FILES:
        bid = resource_build_ids[path]
        fid = resource_file_ids[path]
        name = basename(path)
        lines.append(f"\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")

    lines.append(f"\t\t{ID_ASSETS_BUILD} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ID_ASSETS_FILE} /* Assets.xcassets */; }};")

    for fw_name, fw_short in FRAMEWORKS:
        bid = fw_build_ids[fw_name]
        fid = fw_file_ids[fw_name]
        lines.append(f"\t\t{bid} /* {fw_name} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fw_name} */; }};")

    for path in TEST_FILES:
        bid = test_build_ids[path]
        fid = test_file_ids[path]
        name = basename(path)
        lines.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")

    lines.append("/* End PBXBuildFile section */")
    return "\n".join(lines)


def section_pbx_file_reference():
    lines = ["/* Begin PBXFileReference section */"]

    for path in SWIFT_FILES:
        fid = swift_file_ids[path]
        name = basename(path)
        lines.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {pbx_string(name)}; sourceTree = \"<group>\"; }};")

    for path in RESOURCE_FILES:
        fid = resource_file_ids[path]
        name = basename(path)
        ft = file_type_for(path)
        lines.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = {pbx_string(name)}; sourceTree = \"<group>\"; }};")

    lines.append(f"\t\t{ID_ASSETS_FILE} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")

    for fw_name, fw_short in FRAMEWORKS:
        fid = fw_file_ids[fw_name]
        lines.append(f"\t\t{fid} /* {fw_name} */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {fw_name}; path = System/Library/Frameworks/{fw_name}; sourceTree = SDKROOT; }};")

    lines.append(f"\t\t{ID_INFOPLIST} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")

    lines.append(f"\t\t{ID_PRODUCT_REF} /* Niya.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Niya.app; sourceTree = BUILT_PRODUCTS_DIR; }};")

    lines.append(f"\t\t{ID_TEST_PRODUCT_REF} /* NiyaTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = NiyaTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")

    for path in TEST_FILES:
        fid = test_file_ids[path]
        name = basename(path)
        lines.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {pbx_string(name)}; sourceTree = \"<group>\"; }};")

    lines.append("/* End PBXFileReference section */")
    return "\n".join(lines)


def section_pbx_frameworks_build_phase():
    lines = [
        "/* Begin PBXFrameworksBuildPhase section */",
        f"\t\t{ID_FRAMEWORKS_PHASE} /* Frameworks */ = {{",
        "\t\t\tisa = PBXFrameworksBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
    ]
    for fw_name, fw_short in FRAMEWORKS:
        bid = fw_build_ids[fw_name]
        lines.append(f"\t\t\t\t{bid} /* {fw_name} in Frameworks */,")
    lines += [
        "\t\t\t);",
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
        "\t\t};",
        "/* End PBXFrameworksBuildPhase section */",
    ]
    return "\n".join(lines)


def files_in_group(paths):
    """Return a sorted list of file ref IDs for a given directory prefix."""
    result = []
    for path in sorted(paths):
        result.append(swift_file_ids.get(path) or resource_file_ids.get(path))
    return [x for x in result if x]


def section_pbx_group():
    lines = ["/* Begin PBXGroup section */"]

    # Main group
    lines += [
        f"\t\t{ID_MAIN_GROUP} = {{",
        "\t\t\tisa = PBXGroup;",
        "\t\t\tchildren = (",
        f"\t\t\t\t{ID_NIYA_GROUP} /* Niya */,",
        f"\t\t\t\t{ID_TESTS_GROUP} /* NiyaTests */,",
        f"\t\t\t\t{ID_FRAMEWORKS_GROUP} /* Frameworks */,",
        f"\t\t\t\t{ID_PRODUCTS_GROUP} /* Products */,",
        "\t\t\t);",
        "\t\t\tsourceTree = \"<group>\";",
        "\t\t};",
    ]

    # Products group
    lines += [
        f"\t\t{ID_PRODUCTS_GROUP} /* Products */ = {{",
        "\t\t\tisa = PBXGroup;",
        "\t\t\tchildren = (",
        f"\t\t\t\t{ID_PRODUCT_REF} /* Niya.app */,",
        f"\t\t\t\t{ID_TEST_PRODUCT_REF} /* NiyaTests.xctest */,",
        "\t\t\t);",
        "\t\t\tname = Products;",
        "\t\t\tsourceTree = \"<group>\";",
        "\t\t};",
    ]

    # Frameworks group
    lines += [
        f"\t\t{ID_FRAMEWORKS_GROUP} /* Frameworks */ = {{",
        "\t\t\tisa = PBXGroup;",
        "\t\t\tchildren = (",
    ]
    for fw_name, _ in FRAMEWORKS:
        fid = fw_file_ids[fw_name]
        lines.append(f"\t\t\t\t{fid} /* {fw_name} */,")
    lines += [
        "\t\t\t);",
        "\t\t\tname = Frameworks;",
        "\t\t\tsourceTree = \"<group>\";",
        "\t\t};",
    ]

    # Niya group — top-level source folder
    niya_top_children = [
        (swift_file_ids["Niya/NiyaApp.swift"],    "NiyaApp.swift"),
        (swift_file_ids["Niya/ContentView.swift"], "ContentView.swift"),
        (ID_INFOPLIST,                              "Info.plist"),
        (SUBGROUP_IDS["Models"],                   "Models"),
        (SUBGROUP_IDS["Services"],                 "Services"),
        (SUBGROUP_IDS["ViewModels"],               "ViewModels"),
        (SUBGROUP_IDS["Views"],                    "Views"),
        (SUBGROUP_IDS["Onboarding"],              "Onboarding"),
        (SUBGROUP_IDS["Design"],                   "Design"),
        (SUBGROUP_IDS["Resources"],                "Resources"),
    ]
    lines += [
        f"\t\t{ID_NIYA_GROUP} /* Niya */ = {{",
        "\t\t\tisa = PBXGroup;",
        "\t\t\tchildren = (",
    ]
    for gid, gname in niya_top_children:
        lines.append(f"\t\t\t\t{gid} /* {gname} */,")
    lines += [
        "\t\t\t);",
        "\t\t\tname = Niya;",
        "\t\t\tpath = Niya;",
        "\t\t\tsourceTree = \"<group>\";",
        "\t\t};",
    ]

    # Sub-groups helper
    def emit_subgroup(gid, name, path_prefix, children_ids_names, path_str=None):
        """Emit a PBXGroup block."""
        lines.append(f"\t\t{gid} /* {name} */ = {{")
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        for cid, cname in children_ids_names:
            lines.append(f"\t\t\t\t{cid} /* {cname} */,")
        lines.append("\t\t\t);")
        lines.append(f"\t\t\tname = {pbx_string(name)};")
        if path_str:
            lines.append(f"\t\t\tpath = {pbx_string(path_str)};")
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")

    # Models
    emit_subgroup(SUBGROUP_IDS["Models"], "Models", "Models", [
        (swift_file_ids["Niya/Models/QuranScript.swift"], "QuranScript.swift"),
        (swift_file_ids["Niya/Models/Surah.swift"],       "Surah.swift"),
        (swift_file_ids["Niya/Models/Verse.swift"],       "Verse.swift"),
        (swift_file_ids["Niya/Models/AudioDownload.swift"], "AudioDownload.swift"),
        (swift_file_ids["Niya/Models/ReadingPosition.swift"], "ReadingPosition.swift"),
        (swift_file_ids["Niya/Models/RecentSearch.swift"], "RecentSearch.swift"),
        (swift_file_ids["Niya/Models/HadithCollection.swift"], "HadithCollection.swift"),
        (swift_file_ids["Niya/Models/HadithChapter.swift"], "HadithChapter.swift"),
        (swift_file_ids["Niya/Models/Hadith.swift"],       "Hadith.swift"),
        (swift_file_ids["Niya/Models/HadithGrade.swift"],  "HadithGrade.swift"),
        (swift_file_ids["Niya/Models/HadithBookmark.swift"], "HadithBookmark.swift"),
        (swift_file_ids["Niya/Models/QuranBookmark.swift"], "QuranBookmark.swift"),
        (swift_file_ids["Niya/Models/DuaSection.swift"], "DuaSection.swift"),
        (swift_file_ids["Niya/Models/DuaCategory.swift"], "DuaCategory.swift"),
        (swift_file_ids["Niya/Models/Dua.swift"], "Dua.swift"),
        (swift_file_ids["Niya/Models/DuaBookmark.swift"], "DuaBookmark.swift"),
        (swift_file_ids["Niya/Models/RecentHadith.swift"], "RecentHadith.swift"),
        (swift_file_ids["Niya/Models/RecentDua.swift"], "RecentDua.swift"),
        (swift_file_ids["Niya/Models/TajweedRule.swift"], "TajweedRule.swift"),
        (swift_file_ids["Niya/Models/TajweedAnnotation.swift"], "TajweedAnnotation.swift"),
        (swift_file_ids["Niya/Models/TajweedVerse.swift"], "TajweedVerse.swift"),
        (swift_file_ids["Niya/Models/Word.swift"], "Word.swift"),
        (swift_file_ids["Niya/Models/Reciter.swift"], "Reciter.swift"),
        (swift_file_ids["Niya/Models/TranslationEdition.swift"], "TranslationEdition.swift"),
        (swift_file_ids["Niya/Models/TafsirEdition.swift"], "TafsirEdition.swift"),
        (swift_file_ids["Niya/Models/UserLocation.swift"], "UserLocation.swift"),
        (swift_file_ids["Niya/Models/CalculationMethod.swift"], "CalculationMethod.swift"),
        (swift_file_ids["Niya/Models/PrayerTime.swift"], "PrayerTime.swift"),
    ], path_str="Models")

    # Services
    emit_subgroup(SUBGROUP_IDS["Services"], "Services", "Services", [
        (swift_file_ids["Niya/Services/QuranDataService.swift"], "QuranDataService.swift"),
        (swift_file_ids["Niya/Services/AudioService.swift"],     "AudioService.swift"),
        (swift_file_ids["Niya/Services/DownloadStore.swift"],    "DownloadStore.swift"),
        (swift_file_ids["Niya/Services/ReadingPositionStore.swift"], "ReadingPositionStore.swift"),
        (swift_file_ids["Niya/Services/RecentSearchStore.swift"], "RecentSearchStore.swift"),
        (swift_file_ids["Niya/Services/HadithDataService.swift"], "HadithDataService.swift"),
        (swift_file_ids["Niya/Services/HadithBookmarkStore.swift"], "HadithBookmarkStore.swift"),
        (swift_file_ids["Niya/Services/QuranBookmarkStore.swift"], "QuranBookmarkStore.swift"),
        (swift_file_ids["Niya/Services/DuaDataService.swift"], "DuaDataService.swift"),
        (swift_file_ids["Niya/Services/DuaBookmarkStore.swift"], "DuaBookmarkStore.swift"),
        (swift_file_ids["Niya/Services/RecentHadithStore.swift"], "RecentHadithStore.swift"),
        (swift_file_ids["Niya/Services/RecentDuaStore.swift"], "RecentDuaStore.swift"),
        (swift_file_ids["Niya/Services/TajweedService.swift"], "TajweedService.swift"),
        (swift_file_ids["Niya/Services/WordDataService.swift"], "WordDataService.swift"),
        (swift_file_ids["Niya/Services/TafsirService.swift"], "TafsirService.swift"),
        (swift_file_ids["Niya/Services/PrayerTimeCalculator.swift"], "PrayerTimeCalculator.swift"),
        (swift_file_ids["Niya/Services/LocationService.swift"], "LocationService.swift"),
        (swift_file_ids["Niya/Services/PrayerTimeService.swift"], "PrayerTimeService.swift"),
    ], path_str="Services")

    # ViewModels
    emit_subgroup(SUBGROUP_IDS["ViewModels"], "ViewModels", "ViewModels", [
        (swift_file_ids["Niya/ViewModels/SurahListViewModel.swift"],  "SurahListViewModel.swift"),
        (swift_file_ids["Niya/ViewModels/ReaderViewModel.swift"],     "ReaderViewModel.swift"),
        (swift_file_ids["Niya/ViewModels/AudioPlayerViewModel.swift"], "AudioPlayerViewModel.swift"),
        (swift_file_ids["Niya/ViewModels/FollowAlongViewModel.swift"], "FollowAlongViewModel.swift"),
    ], path_str="ViewModels")

    # Views (parent)
    emit_subgroup(SUBGROUP_IDS["Views"], "Views", "Views", [
        (swift_file_ids["Niya/Views/BookmarksView.swift"], "BookmarksView.swift"),
        (SUBGROUP_IDS["Views/SurahList"], "SurahList"),
        (SUBGROUP_IDS["Views/Reader"],    "Reader"),
        (SUBGROUP_IDS["Views/Audio"],     "Audio"),
        (SUBGROUP_IDS["Views/Home"],      "Home"),
        (SUBGROUP_IDS["Views/Settings"],  "Settings"),
        (SUBGROUP_IDS["Views/Hadith"],    "Hadith"),
        (SUBGROUP_IDS["Views/Dua"],       "Dua"),
        (SUBGROUP_IDS["Views/Salah"],     "Salah"),
    ], path_str="Views")

    # Views/SurahList
    emit_subgroup(SUBGROUP_IDS["Views/SurahList"], "SurahList", "Views/SurahList", [
        (swift_file_ids["Niya/Views/SurahList/SurahListView.swift"], "SurahListView.swift"),
        (swift_file_ids["Niya/Views/SurahList/SurahRowView.swift"],  "SurahRowView.swift"),
        (swift_file_ids["Niya/Views/SurahList/SurahSearchView.swift"], "SurahSearchView.swift"),
    ], path_str="SurahList")

    # Views/Reader
    emit_subgroup(SUBGROUP_IDS["Views/Reader"], "Reader", "Views/Reader", [
        (swift_file_ids["Niya/Views/Reader/ReaderContainerView.swift"], "ReaderContainerView.swift"),
        (swift_file_ids["Niya/Views/Reader/ScrollReaderView.swift"],    "ScrollReaderView.swift"),
        (swift_file_ids["Niya/Views/Reader/PageReaderView.swift"],      "PageReaderView.swift"),
        (swift_file_ids["Niya/Views/Reader/VerseRowView.swift"],        "VerseRowView.swift"),
        (swift_file_ids["Niya/Views/Reader/MushaPageView.swift"],       "MushaPageView.swift"),
        (swift_file_ids["Niya/Views/Reader/ReaderSettingsSheet.swift"], "ReaderSettingsSheet.swift"),
        (swift_file_ids["Niya/Views/Reader/TajweedTextView.swift"], "TajweedTextView.swift"),
        (swift_file_ids["Niya/Views/Reader/FollowAlongVerseView.swift"], "FollowAlongVerseView.swift"),
        (swift_file_ids["Niya/Views/Reader/WordView.swift"], "WordView.swift"),
        (swift_file_ids["Niya/Views/Reader/VerseCellView.swift"], "VerseCellView.swift"),
        (swift_file_ids["Niya/Views/Reader/TranslationPickerView.swift"], "TranslationPickerView.swift"),
        (swift_file_ids["Niya/Views/Reader/TafsirSheetView.swift"], "TafsirSheetView.swift"),
    ], path_str="Reader")

    # Views/Audio
    emit_subgroup(SUBGROUP_IDS["Views/Audio"], "Audio", "Views/Audio", [
        (swift_file_ids["Niya/Views/Audio/AudioPlayerBar.swift"], "AudioPlayerBar.swift"),
    ], path_str="Audio")

    # Views/Home
    emit_subgroup(SUBGROUP_IDS["Views/Home"], "Home", "Views/Home", [
        (swift_file_ids["Niya/Views/Home/HomeView.swift"], "HomeView.swift"),
        (swift_file_ids["Niya/Views/Home/ContinueReadingCard.swift"], "ContinueReadingCard.swift"),
        (swift_file_ids["Niya/Views/Home/RecentHadithCard.swift"], "RecentHadithCard.swift"),
        (swift_file_ids["Niya/Views/Home/RecentDuaCard.swift"], "RecentDuaCard.swift"),
    ], path_str="Home")

    # Views/Settings
    emit_subgroup(SUBGROUP_IDS["Views/Settings"], "Settings", "Views/Settings", [
        (swift_file_ids["Niya/Views/Settings/SettingsView.swift"], "SettingsView.swift"),
    ], path_str="Settings")

    # Views/Hadith
    emit_subgroup(SUBGROUP_IDS["Views/Hadith"], "Hadith", "Views/Hadith", [
        (swift_file_ids["Niya/Views/Hadith/HadithTabView.swift"], "HadithTabView.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithCollectionCard.swift"], "HadithCollectionCard.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithCollectionView.swift"], "HadithCollectionView.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithChapterRow.swift"], "HadithChapterRow.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithChapterView.swift"], "HadithChapterView.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithRowView.swift"], "HadithRowView.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithDetailView.swift"], "HadithDetailView.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithBookmarksView.swift"], "HadithBookmarksView.swift"),
        (swift_file_ids["Niya/Views/Hadith/HadithSearchResultRow.swift"], "HadithSearchResultRow.swift"),
    ], path_str="Hadith")

    # Views/Dua
    emit_subgroup(SUBGROUP_IDS["Views/Dua"], "Dua", "Views/Dua", [
        (swift_file_ids["Niya/Views/Dua/DuaTabView.swift"], "DuaTabView.swift"),
        (swift_file_ids["Niya/Views/Dua/DuaSectionView.swift"], "DuaSectionView.swift"),
        (swift_file_ids["Niya/Views/Dua/DuaRowView.swift"], "DuaRowView.swift"),
        (swift_file_ids["Niya/Views/Dua/DuaDetailView.swift"], "DuaDetailView.swift"),
        (swift_file_ids["Niya/Views/Dua/DuaSearchResultRow.swift"], "DuaSearchResultRow.swift"),
    ], path_str="Dua")

    # Views/Salah
    emit_subgroup(SUBGROUP_IDS["Views/Salah"], "Salah", "Views/Salah", [
        (swift_file_ids["Niya/Views/Salah/SalahSheetView.swift"], "SalahSheetView.swift"),
        (swift_file_ids["Niya/Views/Salah/QiblahCompassView.swift"], "QiblahCompassView.swift"),
        (swift_file_ids["Niya/Views/Salah/PrayerTimesListView.swift"], "PrayerTimesListView.swift"),
        (swift_file_ids["Niya/Views/Salah/LocationPickerView.swift"], "LocationPickerView.swift"),
    ], path_str="Salah")

    # Onboarding
    emit_subgroup(SUBGROUP_IDS["Onboarding"], "Onboarding", "Onboarding", [
        (swift_file_ids["Niya/Onboarding/ReaderTips.swift"], "ReaderTips.swift"),
    ], path_str="Onboarding")

    # Design
    emit_subgroup(SUBGROUP_IDS["Design"], "Design", "Design", [
        (swift_file_ids["Niya/Design/NiyaColors.swift"], "NiyaColors.swift"),
        (swift_file_ids["Niya/Design/NiyaFonts.swift"],  "NiyaFonts.swift"),
        (swift_file_ids["Niya/Design/NiyaTheme.swift"],  "NiyaTheme.swift"),
        (swift_file_ids["Niya/Design/NiyaExtensions.swift"], "NiyaExtensions.swift"),
        (swift_file_ids["Niya/Design/NiyaToolbar.swift"], "NiyaToolbar.swift"),
        (swift_file_ids["Niya/Design/FlowLayout.swift"], "FlowLayout.swift"),
        (swift_file_ids["Niya/Design/ViewCompat.swift"], "ViewCompat.swift"),
    ], path_str="Design")

    # Resources (parent)
    emit_subgroup(SUBGROUP_IDS["Resources"], "Resources", "Resources", [
        (SUBGROUP_IDS["Resources/Data"],  "Data"),
        (SUBGROUP_IDS["Resources/Fonts"], "Fonts"),
        (ID_ASSETS_FILE,                  "Assets.xcassets"),
    ], path_str="Resources")

    # Resources/Data
    data_children = [
        (resource_file_ids["Niya/Resources/Data/surahs.json"],        "surahs.json"),
        (resource_file_ids["Niya/Resources/Data/verses_hafs.json"],   "verses_hafs.json"),
        (resource_file_ids["Niya/Resources/Data/verses_indopak.json"],"verses_indopak.json"),
        (resource_file_ids["Niya/Resources/Data/hadith_collections.json"], "hadith_collections.json"),
        (resource_file_ids["Niya/Resources/Data/dua_all.json"], "dua_all.json"),
        (resource_file_ids["Niya/Resources/Data/word_data.json"], "word_data.json"),
        (resource_file_ids["Niya/Resources/Data/noreen_word_data.json"], "noreen_word_data.json"),
        (resource_file_ids["Niya/Resources/Data/translations_index.json"], "translations_index.json"),
    ]
    for tid in ["en_sahih", "en_clearquran", "en_hilali", "fr_hamidullah",
                 "es_cortes", "tr_diyanet", "ur_maududi", "id_indonesian",
                 "bn_bengali", "de_bubenheim", "ru_kuliev", "ms_basmeih", "zh_jian"]:
        fname = f"translation_{tid}.json"
        data_children.append((resource_file_ids[f"Niya/Resources/Data/{fname}"], fname))
    for coll_id in ["bukhari", "muslim", "abudawud", "tirmidhi", "nasai", "ibnmajah",
                     "malik", "ahmed", "darimi", "nawawi", "qudsi", "dehlawi",
                     "aladab", "bulugh", "mishkat", "riyad", "shamail"]:
        fname = f"hadith_{coll_id}.json"
        data_children.append((resource_file_ids[f"Niya/Resources/Data/{fname}"], fname))
    emit_subgroup(SUBGROUP_IDS["Resources/Data"], "Data", "Resources/Data", data_children, path_str="Data")

    # Resources/Fonts
    emit_subgroup(SUBGROUP_IDS["Resources/Fonts"], "Fonts", "Resources/Fonts", [
        (resource_file_ids["Niya/Resources/Fonts/KFGQPC Uthmanic Script HAFS Regular.otf"], "KFGQPC Uthmanic Script HAFS Regular.otf"),
        (resource_file_ids["Niya/Resources/Fonts/ScheherazadeNew-Regular.ttf"], "ScheherazadeNew-Regular.ttf"),
        (resource_file_ids["Niya/Resources/Fonts/NotoNaskhArabic-Regular.ttf"], "NotoNaskhArabic-Regular.ttf"),
    ], path_str="Fonts")

    # NiyaTests group
    test_children = [(test_file_ids[p], basename(p)) for p in TEST_FILES]
    emit_subgroup(ID_TESTS_GROUP, "NiyaTests", "NiyaTests", test_children, path_str="NiyaTests")

    lines.append("/* End PBXGroup section */")
    return "\n".join(lines)


def section_pbx_container_item_proxy():
    lines = [
        "/* Begin PBXContainerItemProxy section */",
        f"\t\t{ID_CONTAINER_ITEM_PROXY} /* PBXContainerItemProxy */ = {{",
        "\t\t\tisa = PBXContainerItemProxy;",
        f"\t\t\tcontainerPortal = {ID_PROJECT} /* Project object */;",
        "\t\t\tproxyType = 1;",
        f"\t\t\tremoteGlobalIDString = {ID_TARGET};",
        "\t\t\tremoteInfo = Niya;",
        "\t\t};",
        "/* End PBXContainerItemProxy section */",
    ]
    return "\n".join(lines)


def section_pbx_target_dependency():
    lines = [
        "/* Begin PBXTargetDependency section */",
        f"\t\t{ID_TARGET_DEPENDENCY} /* PBXTargetDependency */ = {{",
        "\t\t\tisa = PBXTargetDependency;",
        f"\t\t\ttarget = {ID_TARGET} /* Niya */;",
        f"\t\t\ttargetProxy = {ID_CONTAINER_ITEM_PROXY} /* PBXContainerItemProxy */;",
        "\t\t};",
        "/* End PBXTargetDependency section */",
    ]
    return "\n".join(lines)


def section_pbx_native_target():
    lines = [
        "/* Begin PBXNativeTarget section */",
        f"\t\t{ID_TARGET} /* Niya */ = {{",
        "\t\t\tisa = PBXNativeTarget;",
        f"\t\t\tbuildConfigurationList = {ID_CFGLIST_TARGET} /* Build configuration list for PBXNativeTarget \"Niya\" */;",
        "\t\t\tbuildPhases = (",
        f"\t\t\t\t{ID_SOURCES_PHASE} /* Sources */,",
        f"\t\t\t\t{ID_RESOURCES_PHASE} /* Resources */,",
        f"\t\t\t\t{ID_FRAMEWORKS_PHASE} /* Frameworks */,",
        "\t\t\t);",
        "\t\t\tbuildRules = (",
        "\t\t\t);",
        "\t\t\tdependencies = (",
        "\t\t\t);",
        f"\t\t\tname = {PRODUCT_NAME};",
        f"\t\t\tproductName = {PRODUCT_NAME};",
        f"\t\t\tproductReference = {ID_PRODUCT_REF} /* Niya.app */;",
        "\t\t\tproductType = \"com.apple.product-type.application\";",
        "\t\t};",
        f"\t\t{ID_TEST_TARGET} /* NiyaTests */ = {{",
        "\t\t\tisa = PBXNativeTarget;",
        f"\t\t\tbuildConfigurationList = {ID_CFGLIST_TEST_TARGET} /* Build configuration list for PBXNativeTarget \"NiyaTests\" */;",
        "\t\t\tbuildPhases = (",
        f"\t\t\t\t{ID_TEST_SOURCES_PHASE} /* Sources */,",
        f"\t\t\t\t{ID_TEST_FRAMEWORKS_PHASE} /* Frameworks */,",
        "\t\t\t);",
        "\t\t\tbuildRules = (",
        "\t\t\t);",
        "\t\t\tdependencies = (",
        f"\t\t\t\t{ID_TARGET_DEPENDENCY} /* PBXTargetDependency */,",
        "\t\t\t);",
        "\t\t\tname = NiyaTests;",
        "\t\t\tproductName = NiyaTests;",
        f"\t\t\tproductReference = {ID_TEST_PRODUCT_REF} /* NiyaTests.xctest */;",
        "\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";",
        "\t\t};",
        "/* End PBXNativeTarget section */",
    ]
    return "\n".join(lines)


def section_pbx_project():
    lines = [
        "/* Begin PBXProject section */",
        f"\t\t{ID_PROJECT} /* Project object */ = {{",
        "\t\t\tisa = PBXProject;",
        f"\t\t\tbuildConfigurationList = {ID_CFGLIST_PROJECT} /* Build configuration list for PBXProject \"Niya\" */;",
        "\t\t\tcompatibilityVersion = \"Xcode 14.0\";",
        "\t\t\tdevelopmentRegion = en;",
        "\t\t\thasScannedForEncodings = 0;",
        "\t\t\tknownRegions = (",
        "\t\t\t\ten,",
        "\t\t\t\tBase,",
        "\t\t\t);",
        f"\t\t\tmainGroup = {ID_MAIN_GROUP};",
        f"\t\t\tproductRefGroup = {ID_PRODUCTS_GROUP} /* Products */;",
        "\t\t\tprojectDirPath = \"\";",
        "\t\t\tprojectRoot = \"\";",
        "\t\t\ttargets = (",
        f"\t\t\t\t{ID_TARGET} /* Niya */,",
        f"\t\t\t\t{ID_TEST_TARGET} /* NiyaTests */,",
        "\t\t\t);",
        "\t\t};",
        "/* End PBXProject section */",
    ]
    return "\n".join(lines)


def section_pbx_resources_build_phase():
    lines = [
        "/* Begin PBXResourcesBuildPhase section */",
        f"\t\t{ID_RESOURCES_PHASE} /* Resources */ = {{",
        "\t\t\tisa = PBXResourcesBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
    ]
    for path in RESOURCE_FILES:
        bid = resource_build_ids[path]
        name = basename(path)
        lines.append(f"\t\t\t\t{bid} /* {name} in Resources */,")
    lines.append(f"\t\t\t\t{ID_ASSETS_BUILD} /* Assets.xcassets in Resources */,")
    lines += [
        "\t\t\t);",
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
        "\t\t};",
        "/* End PBXResourcesBuildPhase section */",
    ]
    return "\n".join(lines)


def section_pbx_sources_build_phase():
    lines = [
        "/* Begin PBXSourcesBuildPhase section */",
        f"\t\t{ID_SOURCES_PHASE} /* Sources */ = {{",
        "\t\t\tisa = PBXSourcesBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
    ]
    for path in SWIFT_FILES:
        bid = swift_build_ids[path]
        name = basename(path)
        lines.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
    lines += [
        "\t\t\t);",
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
        "\t\t};",
        "/* End PBXSourcesBuildPhase section */",
    ]
    return "\n".join(lines)


def section_pbx_test_sources_build_phase():
    lines = [
        "/* Begin PBXSourcesBuildPhase section (Tests) */",
        f"\t\t{ID_TEST_SOURCES_PHASE} /* Sources */ = {{",
        "\t\t\tisa = PBXSourcesBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
    ]
    for path in TEST_FILES:
        bid = test_build_ids[path]
        name = basename(path)
        lines.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
    lines += [
        "\t\t\t);",
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
        "\t\t};",
        "/* End PBXSourcesBuildPhase section (Tests) */",
    ]
    return "\n".join(lines)


def section_pbx_test_frameworks_build_phase():
    lines = [
        "/* Begin PBXFrameworksBuildPhase section (Tests) */",
        f"\t\t{ID_TEST_FRAMEWORKS_PHASE} /* Frameworks */ = {{",
        "\t\t\tisa = PBXFrameworksBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
        "\t\t\t);",
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
        "\t\t};",
        "/* End PBXFrameworksBuildPhase section (Tests) */",
    ]
    return "\n".join(lines)


def build_settings_project(config):
    is_debug = config == "Debug"
    lines = [
        "\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;",
        "\t\t\t\tASSET_CATALOG_COMPILER_OPTIMIZATION = space;",
        "\t\t\t\tCLANG_ANALYZER_NONNULL = YES;",
        "\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
        "\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";",
        "\t\t\t\tCLANG_ENABLE_MODULES = YES;",
        "\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;",
        "\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;",
        "\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;",
        "\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;",
        "\t\t\t\tCLANG_WARN_COMMA = YES;",
        "\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;",
        "\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;",
        "\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
        "\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
        "\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;",
        "\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;",
        "\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;",
        "\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;",
        "\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
        "\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_CYCLE = YES;",
        "\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
        "\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
        "\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
        "\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
        "\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;",
        "\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;",
        "\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
        "\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;",
        "\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
        "\t\t\t\tCOPY_PHASE_STRIP = NO;",
        "\t\t\t\tDEBUG_INFORMATION_FORMAT = " + ("dwarf;" if is_debug else "\"dwarf-with-dsym\";"),
        "\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;",
        "\t\t\t\tENABLE_TESTABILITY = " + ("YES;" if is_debug else "NO;"),
        "\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;",
        "\t\t\t\tGCC_DYNAMIC_NO_PIC = " + ("NO;" if is_debug else "YES;"),
        "\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;",
        "\t\t\t\tGCC_OPTIMIZATION_LEVEL = " + ("0;" if is_debug else "s;"),
        "\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = " + ("(\n\t\t\t\t\t\"DEBUG=1\",\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t);" if is_debug else "(\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t);"),
        "\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
        "\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
        "\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;",
        "\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
        "\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;",
        "\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;",
        f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT};",
        "\t\t\t\tMTL_ENABLE_DEBUG_INFO = " + ("INCLUDE_SOURCE;" if is_debug else "NO;"),
        "\t\t\t\tMTL_FAST_MATH = YES;",
        "\t\t\t\tONLY_ACTIVE_ARCH = " + ("YES;" if is_debug else "NO;"),
        "\t\t\t\tSDKROOT = iphoneos;",
        "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = " + ("DEBUG;" if is_debug else "\"\";"),
        "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = " + ("\"-Onone\";" if is_debug else "\"-O\";"),
        "\t\t\t\tVALIDATE_PRODUCT = " + ("NO;" if is_debug else "YES;"),
    ]
    return "\n".join(lines)


def build_settings_target(config):
    is_debug = config == "Debug"
    lines = [
        "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
        f"\t\t\t\tINFOPLIST_FILE = Niya/Info.plist;",
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;",
        "\t\t\t\tDEVELOPMENT_TEAM = MYGKXH6TY4;",
        "\t\t\t\tCURRENT_PROJECT_VERSION = 6;",
        f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT};",
        "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t);",
        "\t\t\t\tMARKETING_VERSION = 1.0;",
        f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";",
        "\t\t\t\tSDKROOT = iphoneos;",
        f"\t\t\t\tSWIFT_VERSION = {SWIFT_VER};",
        "\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;",
        "\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";",
    ]
    return "\n".join(lines)


def build_settings_test_target(config):
    lines = [
        f"\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";",
        f"\t\t\t\tCODE_SIGN_STYLE = Automatic;",
        "\t\t\t\tDEVELOPMENT_TEAM = MYGKXH6TY4;",
        f"\t\t\t\tCURRENT_PROJECT_VERSION = 6;",
        "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;",
        f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT};",
        "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t\t\"@loader_path/Frameworks\",\n\t\t\t\t);",
        f"\t\t\t\tMARKETING_VERSION = 1.0;",
        f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.niya.mobile.tests;",
        f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";",
        f"\t\t\t\tSDKROOT = iphoneos;",
        f"\t\t\t\tSWIFT_VERSION = {SWIFT_VER};",
        "\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;",
        "\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";",
        "\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Niya.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Niya\";",
    ]
    return "\n".join(lines)


def section_xcbuild_configuration_list():
    debug_proj_settings   = build_settings_project("Debug")
    release_proj_settings = build_settings_project("Release")
    debug_tgt_settings    = build_settings_target("Debug")
    release_tgt_settings  = build_settings_target("Release")
    debug_test_settings   = build_settings_test_target("Debug")
    release_test_settings = build_settings_test_target("Release")

    lines = [
        "/* Begin XCBuildConfiguration section */",
        f"\t\t{ID_DEBUG_PROJECT} /* Debug */ = {{",
        "\t\t\tisa = XCBuildConfiguration;",
        "\t\t\tbuildSettings = {",
        debug_proj_settings,
        "\t\t\t};",
        "\t\t\tname = Debug;",
        "\t\t};",
        f"\t\t{ID_RELEASE_PROJECT} /* Release */ = {{",
        "\t\t\tisa = XCBuildConfiguration;",
        "\t\t\tbuildSettings = {",
        release_proj_settings,
        "\t\t\t};",
        "\t\t\tname = Release;",
        "\t\t};",
        f"\t\t{ID_DEBUG_TARGET} /* Debug */ = {{",
        "\t\t\tisa = XCBuildConfiguration;",
        "\t\t\tbuildSettings = {",
        debug_tgt_settings,
        "\t\t\t};",
        "\t\t\tname = Debug;",
        "\t\t};",
        f"\t\t{ID_RELEASE_TARGET} /* Release */ = {{",
        "\t\t\tisa = XCBuildConfiguration;",
        "\t\t\tbuildSettings = {",
        release_tgt_settings,
        "\t\t\t};",
        "\t\t\tname = Release;",
        "\t\t};",
        f"\t\t{ID_DEBUG_TEST_TARGET} /* Debug */ = {{",
        "\t\t\tisa = XCBuildConfiguration;",
        "\t\t\tbuildSettings = {",
        debug_test_settings,
        "\t\t\t};",
        "\t\t\tname = Debug;",
        "\t\t};",
        f"\t\t{ID_RELEASE_TEST_TARGET} /* Release */ = {{",
        "\t\t\tisa = XCBuildConfiguration;",
        "\t\t\tbuildSettings = {",
        release_test_settings,
        "\t\t\t};",
        "\t\t\tname = Release;",
        "\t\t};",
        "/* End XCBuildConfiguration section */",
    ]
    return "\n".join(lines)


def section_xcconfiguration_list():
    lines = [
        "/* Begin XCConfigurationList section */",
        f"\t\t{ID_CFGLIST_PROJECT} /* Build configuration list for PBXProject \"Niya\" */ = {{",
        "\t\t\tisa = XCConfigurationList;",
        "\t\t\tbuildConfigurations = (",
        f"\t\t\t\t{ID_DEBUG_PROJECT} /* Debug */,",
        f"\t\t\t\t{ID_RELEASE_PROJECT} /* Release */,",
        "\t\t\t);",
        "\t\t\tdefaultConfigurationIsVisible = 0;",
        "\t\t\tdefaultConfigurationName = Release;",
        "\t\t};",
        f"\t\t{ID_CFGLIST_TARGET} /* Build configuration list for PBXNativeTarget \"Niya\" */ = {{",
        "\t\t\tisa = XCConfigurationList;",
        "\t\t\tbuildConfigurations = (",
        f"\t\t\t\t{ID_DEBUG_TARGET} /* Debug */,",
        f"\t\t\t\t{ID_RELEASE_TARGET} /* Release */,",
        "\t\t\t);",
        "\t\t\tdefaultConfigurationIsVisible = 0;",
        "\t\t\tdefaultConfigurationName = Release;",
        "\t\t};",
        f"\t\t{ID_CFGLIST_TEST_TARGET} /* Build configuration list for PBXNativeTarget \"NiyaTests\" */ = {{",
        "\t\t\tisa = XCConfigurationList;",
        "\t\t\tbuildConfigurations = (",
        f"\t\t\t\t{ID_DEBUG_TEST_TARGET} /* Debug */,",
        f"\t\t\t\t{ID_RELEASE_TEST_TARGET} /* Release */,",
        "\t\t\t);",
        "\t\t\tdefaultConfigurationIsVisible = 0;",
        "\t\t\tdefaultConfigurationName = Release;",
        "\t\t};",
        "/* End XCConfigurationList section */",
    ]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Assemble the full file
# ---------------------------------------------------------------------------

def generate():
    sections = [
        section_pbx_build_file(),
        section_pbx_container_item_proxy(),
        section_pbx_file_reference(),
        section_pbx_frameworks_build_phase(),
        section_pbx_group(),
        section_pbx_native_target(),
        section_pbx_project(),
        section_pbx_resources_build_phase(),
        section_pbx_sources_build_phase(),
        section_pbx_target_dependency(),
        section_pbx_test_sources_build_phase(),
        section_pbx_test_frameworks_build_phase(),
        section_xcbuild_configuration_list(),
        section_xcconfiguration_list(),
    ]

    body = "\n\n".join(sections)

    content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{

{body}

\t}};
\trootObject = {ID_PROJECT} /* Project object */;
}}
"""
    os.makedirs(os.path.dirname(PBXPROJ_PATH), exist_ok=True)
    with open(PBXPROJ_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Written: {PBXPROJ_PATH}")


if __name__ == "__main__":
    generate()
