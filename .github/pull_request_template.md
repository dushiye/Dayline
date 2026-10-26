## What changed

## How you checked it

- [ ] `swift test --package-path Packages/DaylineCore --scratch-path "$HOME/Library/Caches/DaylineSwiftBuild/DaylineCore"` if core logic changed
- [ ] Mac `xcodebuild test` if Mac behavior changed
- [ ] Install scripts still refuse to touch `~/Library/Application Support/Dayline`

## Data and signing

- [ ] No personal tasks, database files, logs, or credentials
- [ ] No `DEVELOPMENT_TEAM`, certificate, or license file added without agreement
