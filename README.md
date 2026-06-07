# MacCleanerPro

A native, SwiftUI-based macOS cleanup utility that scans real system folders, measures actual reclaimable disk space, and lets you selectively clean it — with safety levels, snapshots, and scheduled maintenance built in.

> Built entirely with Swift Package Manager and AppKit/SwiftUI — no Electron, no third-party frameworks, no telemetry.

## Highlights

- **Real, on-disk measurement** — every category reports the *actual allocated size* of the files it found (`fileAllocatedSize` / `totalFileAllocatedSize`), not estimates.
- **16 scan categories** spanning caches, logs, developer tooling, browsers, the Trash, orphaned app data, and more (see below).
- **Safety-tiered cleanup plan** — every category is labeled `Safe`, `Review`, or `Manual`; Safe Mode restricts the cleanup plan to low-risk categories only.
- **Snapshot manifests** — before cleaning, MacCleanerPro can write a JSON manifest of everything it's about to touch (`~/Library/Application Support/MacCleanerPro/Snapshots`) for auditability.
- **Live activity & health score** — a running log of scans/cleanups plus a computed health score that balances free space, risk, and safety profile.
- **Scheduled maintenance** — installs a `launchd` LaunchAgent for daily/weekly/monthly background scans.
- **15 languages** — runtime localization (Turkish source strings with English and 13 other language packs, graceful fallback to English).
- **Reports & exports** — exports a plain-text scan/cleanup report to the Desktop.

## Scan categories

| Category | Safety | What it measures |
|---|---|---|
| User Cache | Safe | `~/Library/Caches` and (with deep scan) container cache layers |
| Log & Crash Archives | Safe | `~/Library/Logs`, `CrashReporter`, container logs |
| Xcode DerivedData | Safe | `~/Library/Developer/Xcode/DerivedData` |
| Device Support & Simulator Cache | Safe | iOS DeviceSupport bundles, CoreSimulator caches |
| System Temporary Files | Safe | Stale files under the per-user `TMPDIR` (3+ days untouched) |
| Browser Caches | Safe | Safari, Chrome, Firefox, Brave, Edge, Arc, Opera, Vivaldi cache folders |
| Developer Package Caches | Safe | Homebrew, npm, pip, Yarn, CocoaPods, cargo, go, Gradle, Bundler caches |
| Mail Downloads | Review | Apple Mail's locally cached attachment folders |
| iOS Finder Backups | Review | `MobileSync` backups created through Finder |
| Large Download Files | Review | Large, aged files under `~/Downloads` (configurable threshold/age) |
| Large & Old User Files | Review | 200 MB+ files untouched for 45+ days under Documents, Desktop, Movies, Music, Pictures |
| Trash | Review | `~/.Trash` contents — **permanently deleted**, not re-trashed (irreversible) |
| Xcode Archives | Review | Past `.xcarchive` build/distribution bundles |
| Leftover Files From Removed Apps | Review | Library data whose bundle-identifier-shaped folder name no longer matches any installed app |
| Docker System Data | Manual | Reclaimable space via `docker system df`, cleaned with `docker system prune -af` |
| Photos Library Cache | Informational | Size of derived/cache data inside the Photos library — reported only, never deleted |

Safety levels:
- **Safe** — selected by default, regenerates automatically (caches, build artifacts, temp files).
- **Review** — requires explicit selection; touches user data, archives, or is irreversible.
- **Manual** — requires an external tool (Docker CLI) or is informational only.

## Why these particular folders?

Every root is read with `FileManager`, sizes are computed by recursively summing **allocated** size (not logical size) while explicitly skipping symbolic links, and only **direct children** of each root are listed as individually selectable/trashable items — so a single click never silently deletes more than what's shown. The "Leftover Files From Removed Apps" scanner cross-references real `CFBundleIdentifier` values read from `/Applications`, `/System/Applications`, and `~/Applications`, and skips Apple's own (`com.apple.*`) identifiers and anything under 1 MB to minimize false positives.

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (`arm64`) — see `build_app.sh` for the build architecture
- Xcode / Swift 6.0 toolchain to build from source

## Building & running

```bash
# Debug build via Swift Package Manager
swift build

# Or produce a signed, distributable .app bundle + .pkg installer
./build_app.sh
open dist/MacCleanerPro.app
```

`build_app.sh` compiles a release build, assembles `dist/MacCleanerPro.app` with `Resources/Info.plist`, ad-hoc code-signs it, and packages it into `dist/MacCleanerPro.pkg`.

## Project structure

```
Sources/
├── MacCleanerProApp.swift     # App entry point / scene setup
├── AppModels.swift            # Domain models: categories, safety levels, scan options/results
├── AppViewModel.swift         # Scan/cleanup orchestration, preferences, LaunchAgent, notifications
├── CleanupService.swift       # Real filesystem scanning & cleanup execution
├── ContentView.swift          # Main SwiftUI interface (dashboard, plan, automation, reports)
├── OnboardingView.swift       # First-run setup flow (profile, theme, language)
├── Localization.swift         # L10n.tr/format + per-language string tables
└── LocalizationRuntime.swift  # Language selection & runtime localization plumbing
```

## Safety & privacy

- All cleanup actions move items to the Trash (`FileManager.trashItem`) by default; only the Trash category itself performs a permanent delete, mirroring Finder's "Empty Trash."
- External processes (Docker CLI, `launchctl`) run with a minimal, explicit environment to avoid profile-injection.
- No network access, analytics, or telemetry — every number shown comes from a live scan of your own disk.

## License

Copyright © 2025 Mert Sert. All rights reserved.
