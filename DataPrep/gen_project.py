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

BUNDLE_ID    = "com.niya.app"
PRODUCT_NAME = "Niya"
DEPLOYMENT   = "26.0"
SWIFT_VER    = "6.2"

# Swift source files — paths relative to project root
SWIFT_FILES = [
    "Niya/NiyaApp.swift",
    "Niya/ContentView.swift",
    "Niya/Models/QuranScript.swift",
    "Niya/Models/Surah.swift",
    "Niya/Models/Verse.swift",
    "Niya/Models/AudioDownload.swift",
    "Niya/Services/QuranDataService.swift",
    "Niya/Services/AudioService.swift",
    "Niya/Services/DownloadStore.swift",
    "Niya/ViewModels/SurahListViewModel.swift",
    "Niya/ViewModels/ReaderViewModel.swift",
    "Niya/ViewModels/AudioPlayerViewModel.swift",
    "Niya/Views/SurahList/SurahListView.swift",
    "Niya/Views/SurahList/SurahRowView.swift",
    "Niya/Views/SurahList/SurahSearchView.swift",
    "Niya/Views/Reader/ReaderContainerView.swift",
    "Niya/Views/Reader/ScrollReaderView.swift",
    "Niya/Views/Reader/PageReaderView.swift",
    "Niya/Views/Reader/VerseRowView.swift",
    "Niya/Views/Reader/MushaPageView.swift",
    "Niya/Views/Audio/AudioPlayerBar.swift",
    "Niya/Views/Settings/SettingsView.swift",
    "Niya/Design/NiyaColors.swift",
    "Niya/Design/NiyaFonts.swift",
    "Niya/Design/NiyaTheme.swift",
]

# Resource files — paths relative to project root
RESOURCE_FILES = [
    "Niya/Resources/Data/surahs.json",
    "Niya/Resources/Data/verses_hafs.json",
    "Niya/Resources/Data/verses_indopak.json",
    "Niya/Resources/Fonts/KFGQPC Uthmanic Script HAFS Regular.otf",
    "Niya/Resources/Fonts/ScheherazadeNew-Regular.ttf",
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
ID_PRODUCTS_GROUP   = new_id()
ID_MAIN_GROUP       = new_id()
ID_NIYA_GROUP       = new_id()   # "Niya" source group

# Build phases
ID_SOURCES_PHASE    = new_id()
ID_RESOURCES_PHASE  = new_id()
ID_FRAMEWORKS_PHASE = new_id()

# Build configurations
ID_DEBUG_PROJECT    = new_id()
ID_RELEASE_PROJECT  = new_id()
ID_DEBUG_TARGET     = new_id()
ID_RELEASE_TARGET   = new_id()
ID_CFGLIST_PROJECT  = new_id()
ID_CFGLIST_TARGET   = new_id()

# Product file reference
ID_PRODUCT_REF      = new_id()

# Sub-groups inside Niya/
SUBGROUP_IDS = {
    "Models":             new_id(),
    "Services":           new_id(),
    "ViewModels":         new_id(),
    "Views":              new_id(),
    "Views/SurahList":    new_id(),
    "Views/Reader":       new_id(),
    "Views/Audio":        new_id(),
    "Views/Settings":     new_id(),
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
    ], path_str="Models")

    # Services
    emit_subgroup(SUBGROUP_IDS["Services"], "Services", "Services", [
        (swift_file_ids["Niya/Services/QuranDataService.swift"], "QuranDataService.swift"),
        (swift_file_ids["Niya/Services/AudioService.swift"],     "AudioService.swift"),
        (swift_file_ids["Niya/Services/DownloadStore.swift"],    "DownloadStore.swift"),
    ], path_str="Services")

    # ViewModels
    emit_subgroup(SUBGROUP_IDS["ViewModels"], "ViewModels", "ViewModels", [
        (swift_file_ids["Niya/ViewModels/SurahListViewModel.swift"],  "SurahListViewModel.swift"),
        (swift_file_ids["Niya/ViewModels/ReaderViewModel.swift"],     "ReaderViewModel.swift"),
        (swift_file_ids["Niya/ViewModels/AudioPlayerViewModel.swift"], "AudioPlayerViewModel.swift"),
    ], path_str="ViewModels")

    # Views (parent)
    emit_subgroup(SUBGROUP_IDS["Views"], "Views", "Views", [
        (SUBGROUP_IDS["Views/SurahList"], "SurahList"),
        (SUBGROUP_IDS["Views/Reader"],    "Reader"),
        (SUBGROUP_IDS["Views/Audio"],     "Audio"),
        (SUBGROUP_IDS["Views/Settings"],  "Settings"),
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
    ], path_str="Reader")

    # Views/Audio
    emit_subgroup(SUBGROUP_IDS["Views/Audio"], "Audio", "Views/Audio", [
        (swift_file_ids["Niya/Views/Audio/AudioPlayerBar.swift"], "AudioPlayerBar.swift"),
    ], path_str="Audio")

    # Views/Settings
    emit_subgroup(SUBGROUP_IDS["Views/Settings"], "Settings", "Views/Settings", [
        (swift_file_ids["Niya/Views/Settings/SettingsView.swift"], "SettingsView.swift"),
    ], path_str="Settings")

    # Design
    emit_subgroup(SUBGROUP_IDS["Design"], "Design", "Design", [
        (swift_file_ids["Niya/Design/NiyaColors.swift"], "NiyaColors.swift"),
        (swift_file_ids["Niya/Design/NiyaFonts.swift"],  "NiyaFonts.swift"),
        (swift_file_ids["Niya/Design/NiyaTheme.swift"],  "NiyaTheme.swift"),
    ], path_str="Design")

    # Resources (parent)
    emit_subgroup(SUBGROUP_IDS["Resources"], "Resources", "Resources", [
        (SUBGROUP_IDS["Resources/Data"],  "Data"),
        (SUBGROUP_IDS["Resources/Fonts"], "Fonts"),
        (ID_ASSETS_FILE,                  "Assets.xcassets"),
    ], path_str="Resources")

    # Resources/Data
    emit_subgroup(SUBGROUP_IDS["Resources/Data"], "Data", "Resources/Data", [
        (resource_file_ids["Niya/Resources/Data/surahs.json"],        "surahs.json"),
        (resource_file_ids["Niya/Resources/Data/verses_hafs.json"],   "verses_hafs.json"),
        (resource_file_ids["Niya/Resources/Data/verses_indopak.json"],"verses_indopak.json"),
    ], path_str="Data")

    # Resources/Fonts
    emit_subgroup(SUBGROUP_IDS["Resources/Fonts"], "Fonts", "Resources/Fonts", [
        (resource_file_ids["Niya/Resources/Fonts/KFGQPC Uthmanic Script HAFS Regular.otf"], "KFGQPC Uthmanic Script HAFS Regular.otf"),
        (resource_file_ids["Niya/Resources/Fonts/ScheherazadeNew-Regular.ttf"], "ScheherazadeNew-Regular.ttf"),
    ], path_str="Fonts")

    lines.append("/* End PBXGroup section */")
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
        f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
        f"\t\t\t\tINFOPLIST_FILE = Niya/Info.plist;",
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;",
        "\t\t\t\tCURRENT_PROJECT_VERSION = 1;",
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


def section_xcbuild_configuration_list():
    debug_proj_settings   = build_settings_project("Debug")
    release_proj_settings = build_settings_project("Release")
    debug_tgt_settings    = build_settings_target("Debug")
    release_tgt_settings  = build_settings_target("Release")

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
        "/* End XCConfigurationList section */",
    ]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Assemble the full file
# ---------------------------------------------------------------------------

def generate():
    sections = [
        section_pbx_build_file(),
        section_pbx_file_reference(),
        section_pbx_frameworks_build_phase(),
        section_pbx_group(),
        section_pbx_native_target(),
        section_pbx_project(),
        section_pbx_resources_build_phase(),
        section_pbx_sources_build_phase(),
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
