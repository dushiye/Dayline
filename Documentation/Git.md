# Dayline 版本管理

私人仓库：**https://github.com/dushiye/Dayline**

仓库只跟踪 `Dayline/` 这一层。稳定分支是 `main`。当前基线标签是 `v1.1.0-baseline`，对应应用版本 **1.1.0（build 2）**。

## 基线记录的测试

打 `v1.1.0-baseline` 时没有重新运行测试，也没有启动正式数据库。标签引用的是 2026-10-25 已经完成的验收：

- Xcode 27.1（27A9275），Apple Swift 6.4，记录时的系统是 macOS 27.0（26A428）
- 部署目标 macOS 14，架构 arm64
- Xcode `DaylineTests`：**42/42 通过，0 失败**。依据是 [QA.md](QA.md) 的「Xcode XCTest」记录；原始日志在本地 `build/xcode-test-final-source.log`，不纳入 Git
- Swift Package Manager 同一次验收执行 42 项，其中 1 项按设计跳过，0 失败

之后的提交必须写明自己实际跑过哪些测试，不能把这次历史记录说成新的执行结果。

## 日常开发

1. 从最新的 `main` 开始。小改动可以直接在 `main` 上形成一次清晰提交；有风险的功能或数据迁移使用独立分支，验证后再合并。
2. 修改后运行相关自动化测试。发布前再做必要回归。
3. 检查 `git status` 和 `git diff`。按路径暂存，不要使用 `git add .`。
4. 提交，并把已经验证的提交推送到 `origin`。
5. 只有验证通过的状态才打版本 Tag。未验证的工作区修改不能标成稳定版本。

```bash
git status
git diff
git add Sources/Dayline/某文件.swift
git commit -m "说明这次改动为什么需要"
git push origin main
```

独立分支示例：

```bash
git switch -c feature/短名称
# 开发、测试、提交
git push -u origin feature/短名称
git switch main
git merge --no-ff feature/短名称
git push origin main
```

## 创建新版本

正式 Release 使用版本号和附注标签。先确认该提交已经通过当时要求的测试，再打标签并推送。

```bash
git tag -a v1.2.0 -m "Dayline 1.2.0"
git push origin main
git push origin v1.2.0
```

GitHub 上的 Release 应指向这个 Tag。不要把仓库改为 Public。

## 恢复以前的代码

查看基线而不移动 `main`：

```bash
git switch --detach v1.1.0-baseline
```

看完后回到当前开发线：

```bash
git switch main
```

把某个文件恢复成基线内容，再单独提交：

```bash
git restore --source v1.1.0-baseline -- Sources/Dayline/某文件.swift
```

这些操作只改变代码。它们不会替换、降级或迁移 `~/Library/Application Support/Dayline/Dayline.store`。

## 保护与恢复 SwiftData 数据

正式库、WAL、SHM、升级快照和 `Automatic Backups/` 都在 Application Support，不在本仓库。应用运行时不要手工替换这些文件。

- 菜单「导出备份…」生成 schemaVersion=2 的 JSON。
- 「从备份恢复…」会先写 `Before-Restore-<UUID>.json`，校验失败不替换当前数据。
- 升级到 v1.1 前的 SQLite 快照是同目录的 `Dayline.store.before-v1.1.sqlite`。
- 每日自动备份是 `Dayline-Auto-yyyy-MM-dd.json`，同名文件已存在时不覆盖。

如果数据结构变过，恢复旧代码前要确认那份代码能否打开当前数据库。不能打开时，先保留现有 JSON 备份和 SQLite 快照，再用与该数据库结构匹配的代码版本打开，或按应用自己的迁移路径升级。不要为了配合旧代码而清空正式库。

## Cursor 与 Codex

两边阅读同一份 [AGENTS.md](../AGENTS.md)。Cursor 还会加载 `.cursor/rules/dayline-safety.mdc`。规范变更要和代码一起提交，使下一次换用另一个 Agent 时仍然看到相同边界。
