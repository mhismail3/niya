# DataPrep

Offline Python 3 scripts that produce the app's bundled data in
`Niya/Resources/Data`. The app only ever reads `*.json.zlib` (see
`Niya/Services/CompressedJSON.swift`); scripts write plain `.json`, then
`compress_json.py` compresses every `.json` in that folder and removes the
originals. Scripts that read bundled files go through `bundled_json.py`, which
accepts either form.

Inputs are fetched into `source/`, `output/` and `cache/` (all gitignored).
Re-running a fetch hits public APIs; keep their rate limits.

## Bundled file → producer

| Bundled data | Produced by (in order) |
|---|---|
| `surahs`, `verses_hafs`, `verses_indopak` | `fetch_indopak.py`, `validate_indopak.py`, `build_datasets.py` (run inside `source/`) |
| `translation_*`, `translations_index` | `fetch_translations.py`, `fetch_quranenc.py`, `fetch_khattab.py` → `build_translations.py` |
| `tafsir_<edition>/` (per-surah folders) | `build_tafsir.py`, `fetch_tafsir_maududi.py` → `split_tafsir.py` → `fix_tafsir_boundaries.py` |
| `tajweed_hafs` | `build_tajweed.py` (needs `verses_hafs`) |
| `word_data*` (per reciter) | `fetch_word_data.py [--reciter X / --all]` — Arabic text must be QPC Hafs (`text_qpc_hafs`) to match `verses_hafs` and the bundled font |
| `word_data_bukhatir`, `noreen_word_data` | `fetch_bukhatir_audio.py` + `build_bukhatir_word_data.py`, `build_noreen_word_data.py` (Whisper alignment in `venv/`, text from `word_data`) |
| `word_meanings_<lang>` | `fetch_word_meanings.py` |
| `word_morphology`, `root_meanings` | `build_morphology.py` → `build_root_meanings.py` |
| `hadith_*`, `hadith_collections` | `fetch_hadith.py`, `fetch_ahmad_grades.py`, `fetch_sunnah_supplement.py` → `build_hadith.py` (writes `output/hadith/`, copy into Data) → `fetch_darimi_english.py` |
| `dua_all`, `dua_id_migration` | `fetch_dua.py`, `fetch_dua_sources.py`, `fetch_hisn_sources.py`, `build_quranic_duas.py` → `build_dua_v2.py` → `patch_dua_sources.py` |

Finish every change with `python3 compress_json.py`.

## Validation

```bash
cd DataPrep && python3 -m unittest test_translations test_khattab test_fetch_quranenc test_build_hadith
```

`test_build_hadith` skips until `build_hadith.py` has produced `output/hadith/`.
The app-side guards are the Swift suites `WordDataIntegrityTests`,
`HadithDataIntegrityTests`, `TafsirDataIntegrityTests` and
`IndoPakDataIntegrityTests`.
