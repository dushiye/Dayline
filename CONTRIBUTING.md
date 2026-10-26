# Contributing to Dayline

Thanks for looking at the project. The useful contributions right now are bug reports, small Mac fixes, and clearer docs. The iPhone app is experimental.

## Before you start

- macOS 14 or later, plus Xcode or the Command Line Tools.
- Read [AGENTS.md](AGENTS.md) if you use a coding agent.
- Do not send personal tasks, database files, logs from your real library, or signing credentials.

## Build and test

```bash
scripts/check-environment.sh
scripts/build-macos.sh
swift test --package-path Packages/DaylineCore \
  --scratch-path "$HOME/Library/Caches/DaylineSwiftBuild/DaylineCore"
xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" \
  ONLY_ACTIVE_ARCH=YES test
```

The Dayline scheme tests set `DAYLINE_XCTEST_MODE=1` and use a temporary store. Keep that setting. Do not point tests at `~/Library/Application Support/Dayline`.

Install only into a path you choose. Replacing `~/Applications/Dayline.app` requires `DAYLINE_REPLACE_INSTALLED=yes`.

## Project map

- `Packages/DaylineCore` — calendar, recurrence, and planning logic. No SwiftData.
- `Packages/DaylineData` — SwiftData models and the store.
- `Sources/Dayline` — the Mac app.
- `Sources/DaylineIOS` — the experimental iPhone app.
- `Tests/Fixtures` — two synthetic files used by migration tests. Do not replace them with a personal database.

Open `Dayline.xcodeproj`. After adding or removing source files, run `python3 scripts/generate-project.py` and review the diff.

## Pull requests

- One focused change per pull request.
- Describe what you verified.
- Leave the bundle identifiers `app.dayline.mac` and `app.dayline.ios` unchanged unless the maintainer asks.
- The license is MIT. Do not change it, add a `DEVELOPMENT_TEAM`, or add third-party packages without asking first.
- User-facing Mac copy is Chinese. Match the existing wording.

## Reporting bugs

Include the macOS version, whether you installed from source, and the steps. If the bug depends on your data, describe the shape of the data (for example “a weekly task with no due date”) instead of pasting the real title.
