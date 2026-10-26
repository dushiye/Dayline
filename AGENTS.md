# Dayline Agent 规范

Cursor、Codex 和其他 Coding Agent 都遵守本文件。硬性禁令同时写在 `.cursor/rules/dayline-safety.mdc`。仓库只包含 `Dayline/` 目录，不要把上一级「个人效率系统」纳入 Git。

## For coding agents

Dayline is a local-first macOS app (SwiftUI, SwiftData, no third-party packages). iOS is experimental and does not sync with Mac. Open `Dayline.xcodeproj`, not the repository folder: the root `Package.swift` makes Xcode treat the folder as a Swift package.

- Build and install with `scripts/check-environment.sh`, `scripts/build-macos.sh`, and `scripts/install-macos.sh`. The copy-paste prompt is in `docs/INSTALL_WITH_AI.md`.
- Tests use temporary stores. The Xcode `Dayline` scheme sets `DAYLINE_XCTEST_MODE=1`.
- Never open, copy, replace, or delete `~/Library/Application Support/Dayline/`.
- Never replace `~/Applications/Dayline.app` unless the user explicitly confirms.
- Do not ask for Apple ID passwords, private keys, or a paid Developer Program membership.
- Do not disable Gatekeeper, SIP, or other system security settings.
- Do not change repository visibility, rewrite history, or force-push.
- Do not commit a `DEVELOPMENT_TEAM`, provisioning profile, certificate, or personal database.
- The project is MIT licensed. Do not change `LICENSE` or add another license.

## 数据与身份

1. 不得清空、覆盖、删除或重建正式数据库：`~/Library/Application Support/Dayline/Dayline.store`，以及同目录的 WAL、SHM、`Dayline.store.before-v1.1.sqlite` 和 `Automatic Backups/`。不要在没有 `DAYLINE_XCTEST_MODE=1` 且没有 `--qa-store` 时启动 App。
2. 不得修改 Bundle Identifier `app.dayline.mac`，也不得修改测试包 `app.dayline.mac.tests`。
3. 未经隔离库迁移验证，不得修改默认目录名 `Dayline`、文件名 `Dayline.store` 或 `ModelConfiguration` 名 `"Dayline"`。
4. 测试必须使用内存容器、`temporaryDirectory` 或 `--qa-store` 指向的临时库。Xcode scheme `Dayline` 的 Test Action 必须保持 `DAYLINE_XCTEST_MODE=1`，且 `shouldUseLaunchSchemeArgsEnv="NO"`。
5. 数据模型变化必须在合成夹具上验证从旧库向前迁移。迁移测试复制 `Tests/Fixtures/v1.store` 到临时目录后再打开，不得改写夹具原件。
6. 不得提交真实用户数据、数据库、备份、导出或密钥。`git add .` 不允许。只有 `Tests/Fixtures/v1.store` 和 `Tests/Fixtures/v1-backup.json` 是经过核对的合成夹具例外。
7. 不允许为了通过测试而删除重要测试或降低验证标准。

## 开发与发布

8. 每次独立功能或修复使用清晰的 Git commit。有风险的改动放在独立分支，验证通过后再合并到 `main`。
9. 修改后运行相关自动化测试。正式发布前完成必要回归，至少包括受影响的脚本测试；发布候选应跑通 Xcode `Dayline` scheme 的测试。
10. 只有已经验证的提交可以打稳定版本 Tag。Tag 使用版本号，例如 `v1.1.0-baseline`。不要把未验证的修改标成稳定版本。
11. 验证通过后可以把对应提交推送到 `origin`。不要自行把仓库改成 Public，不要改写历史，不要强制推送。不要把 `DEVELOPMENT_TEAM`、证书或个人数据库提交进 Git。
12. 保留历史提交和 Tag。恢复代码使用 Git；恢复 SwiftData 使用应用内 JSON 备份或升级快照。检出旧代码不会把已升级的数据库退回旧结构。结构变化时要同时保留匹配的备份，并确认迁移兼容。

## 常用命令

在仓库根目录执行。DerivedData 放在缓存目录，避免桌面目录影响签名。

```bash
swift test --package-path Packages/DaylineCore \
  --scratch-path "$HOME/Library/Caches/DaylineSwiftBuild/DaylineCore"

xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" \
  ONLY_ACTIVE_ARCH=YES test
```

On this Desktop, `swift test` without `--scratch-path` can fail code signing because Finder metadata is added to the build products. The Xcode command above already keeps DerivedData in the cache.

`scripts/test-native.sh`、`scripts/test-v11.sh`、`scripts/test-planning.sh`、`scripts/test-export.sh` 使用临时库或纯计算。不要用 `scripts/install.sh` 或 `~/Applications/Dayline.app` 做测试。界面验收必须带 `--qa-store` 指向临时库。

日常提交、推送、打 Tag，以及代码回退和数据库恢复的区别，见 [Documentation/Git.md](Documentation/Git.md)。
