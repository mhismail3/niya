# Niya

SwiftUI iOS app (iPhone + iPad) for reading the Quran (Hafs/IndoPak scripts,
tajweed, word-by-word with reciter timing, tafsir, morphology), hadith and dua
collections, and prayer times with notifications, Qiblah and widgets. Fully
offline except recitation audio streaming/downloads and an optional
prayer-time cross-check. Bundle `com.niya.mobile`, team `MYGKXH6TY4`.

## Layout and ownership

| Path | Contents |
|---|---|
| `project.yml` | XcodeGen spec — the only place for targets, settings, versions, schemes |
| `Niya/` | App target: `Models/`, `Services/` (data, audio, persistence), `ViewModels/`, `Views/`, `Design/`, `Protocols/`, `Resources/` |
| `Shared/` | Compiled into **both** app and widget (prayer math, widget data). Must stay extension-safe |
| `NiyaWidgets/` | WidgetKit extension (home + lock screen prayer widgets) |
| `NiyaTests/` | Swift Testing unit tests, hosted by the app |
| `Niya/Resources/Data/` | Bundled `*.json.zlib` data produced by `DataPrep/` (see its README) |
| `Niya/Resources/AppIcon.icon` | Liquid Glass icon (Icon Composer); artwork is `Assets/niya.svg` |
| `scripts/` | `generate-project`, `niya-ios-device`, `publish.sh` |

Membership follows directories; adding a file needs no project edit, only
`scripts/generate-project`. `Niya.xcodeproj` is generated and gitignored.

## Commands

```bash
scripts/generate-project                       # after clone / project.yml edits
scripts/niya-ios-test [--only <Suite>]          # bounded unit-test run; never raw xcodebuild test
scripts/niya-ios-device install                # build + install on a connected device
```

Skills: `.agents/skills/niya-ios` (build/test/device rules — read before any
build work) and `.agents/skills/publish` (TestFlight/App Store, user-invoked).

## Invariants

- Deployment target stays iOS 17; build against the newest SDK (iOS 26 and 27
  must both compile warning-free). Gate newer APIs with `#available`.
- Swift 6 language mode, complete concurrency checking. UI and services are
  `@MainActor`; heavy decoding runs off-main via `Task.detached`.
- Quran Arabic is QPC Hafs encoded and drawn with the bundled KFGQPC font
  (cascade to Noto Naskh). Word text must match `verses_hafs` exactly;
  `WordDataIntegrityTests` enforces it.
- `AudioService` is the single owner of playback, the audio session and the
  persisted reciter speed (including word-clip playback); view models never create players.
- SwiftData: synced models go in the CloudKit configuration (defaults or
  optionals, no unique constraints); `AudioDownload` stays local-only.
  Stores deduplicate on read because CloudKit can create duplicates.
- Release builds enable CloudKit and rely on `scripts/publish.sh`, which refuses
  to ship without the `iCloud.com.niya.mobile` entitlement.
- Prayer times are computed in the location's time zone, never the device's.

## Working rules

- Fix root causes at the owning type; add a behavioral test in the existing
  suite for that area. No test-only hooks beyond dependency injection with
  production defaults; tests must not touch real user defaults, stores or files.
- Never hand-edit generated files (`Niya.xcodeproj`) or bundled data; regenerate
  through `scripts/generate-project` / `DataPrep/`.
- Never install Release builds on a device, archive, upload, or submit without
  an explicit request.
- Keep task scratch out of the repo; delete temporary simulators you create.
