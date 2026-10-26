# Dayline

一款中文优先的原生 macOS 个人效率应用，用「今天的行动」连接学习、科研和健康领域的长期目标。界面使用 SwiftUI 与 AppKit，数据存放在本机 SwiftData 数据库，不需要账号或网络。

当前版本为 **1.1.1（build 3）**。这一版把目标、任务和导出里的日期选择统一成同一个日历弹层，并保留 Ideas、计划导出和只读容量建议。

## 安装与打开

要求 macOS 14 或更新版本。当前构建针对运行构建命令的 Mac 架构；Apple Silicon 产物不能当作 Intel 通用二进制分发。

双击项目根目录的 `安装 Dayline.command`，或执行 `scripts/install.sh`，会在需要时构建，并安装到 `~/Applications/Dayline.app`。若该位置已有旧版，安装脚本会先把旧应用改为带时间戳的备份名称；个人数据库独立保存。

`build/Dayline.app` 是指向已签名应用的快捷链接，在 Finder 中双击即可打开；便携打包产物是 `build/Dayline-macOS.zip`。构建脚本把实际应用组装到 `~/Library/Caches/DaylineBuild/<项目标识>/Dayline.app`，避免桌面 iCloud/File Provider 自动附加 Finder 元数据导致签名失败。安装后的 `~/Applications/Dayline.app` 是独立副本，不依赖构建缓存。开发构建采用本机临时签名，没有 Developer ID 公证；从别的机器下载时，macOS 可能要求通过「右键 → 打开」确认来源。

```bash
open build/Dayline.app
```

首次打开只有三个默认领域与空白工作区。示例数据需要主动选择「试用示例内容」或侧边栏底部菜单中的「添加示例内容」。

## 从源码构建

安装 Apple Command Line Tools（`xcode-select --install`），在此目录执行：

```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools scripts/build-app.sh release
open build/Dayline.app
```

完整 Xcode 不是应用构建的必需条件。此项目使用 Swift Package Manager，无第三方依赖。代码采用 Swift 5 语言模式，部署目标为 macOS 14；当前 Xcode 验证机器使用 Apple Swift 6.4。模型显式遵循 SwiftData 的公开 `PersistentModel` 协议，因此 Command Line Tools 构建与完整 Xcode 构建共用同一套真实 SwiftData 保存和查询实现。

安装完整 Xcode 后，也可以打开原生工程：

```bash
open Dayline.xcodeproj
```

选择 **Dayline** scheme 和 **My Mac**，按 `⌘B` 构建、`⌘R` 运行；测试 target 为 `DaylineTests`，可用 `⌘U` 执行。增删源文件后可运行 `python3 scripts/generate-project.py` 更新工程；生成器会保留 XCTest 的隔离环境配置。

当前机器已配置 Xcode 27.1，许可与首次启动组件完成。命令行原生构建与测试可使用：

```bash
xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" build

xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" test
```

DerivedData 放在缓存目录，是为了避免桌面 File Provider 给签名产物附加 FinderInfo。Xcode Test Action 自动使用临时 QA 数据库；不要删除 scheme 中的 `DAYLINE_XCTEST_MODE=1`。2026-10-26 合并日期选择器前，Xcode 27.1 实际复跑 XCTest 为 **44/44 通过**，其中原有 42 项全部通过。

## 日常使用

- **快速记录**：点击右上角「＋」或按 `⌘N`。任务只需标题，领域、日期和目标都可留空。没有领域、计划日期或关联目标的任务归入收件箱；只有截止日期仍会保留在收件箱。
- **今天**：计划日期或截止日期为今天的任务都会出现，同一任务只展示一次，按领域分组。之前未完成的计划或已逾期的任务单独提示，可主动重新安排日期；应用不会悄悄把旧计划移到今天。
- **日期**：「计划日期」表示准备做的那一天；「截止日期」表示最迟完成日期。截止日在今天之前且未完成才算逾期。判断使用本机日历与时区。目标日期、任务的计划日期和截止日期，以及导出范围，都使用同一个日历弹层。选中的日子按本机日历的当天零点保存；清除任务或目标日期会关掉对应开关。导出范围必须有日期，因此不提供清除。取消编辑不会写入。
- **目标**：可创建长期或短期目标、设置所属领域和目标日期，短期目标可选择一个长期父目标，并关联具体任务。「成果进度」由你手动评估；任务完成比例表示行动进度，两者不自动等同。删除目标会保留相关任务和子目标，并解除直接关联。
- **重复任务**：每日、每周规则在完成当前任务时产生下一条任务。错过的周期会跳过，不一次性补出大量任务；撤销完成后再完成不会重复创建同一期任务。改期不会改变这条重复实例原有的周期身份；删除已生成的下一次行动后，再次完成上一条不会把它重新生成。
- **检索与整理**：侧边栏可切换收件箱、未来一周、目标和三个领域；搜索可查找任务、目标和笔记。任务支持编辑、完成、删除以及列表内拖动排序。
- **Ideas 灵感**：在侧边栏独立记录标题与正文，支持搜索、置顶、归档、领域与目标关联。编辑立即保存；空标题显示为「未命名灵感」。转为任务会保留正文与关联，生成未安排日期的新任务，并保留原灵感。
- **导出中心**：按 `⇧⌘E` 打开原生 sheet，选择计划日期范围或多条灵感，导出 PDF、PNG、Markdown；支持合并文件或分别输出。计划按「计划日期优先，否则截止日期」归属唯一一天，与 Today 的两个日期任一命中提醒口径不同；空日期也会保留。日期范围最多 366 天；PNG 每边最多 16,384 像素且总面积最多 3,200 万像素，超限会提示。重名文件自动添加序号，不覆盖已有文件。
- **历史与建议**：展示计划、实际完成、原计划完成、当天新增、主动改期和删除，并汇总最近 7 / 14 / 30 个有效计划日。实际完成归入完成发生日；原计划完成率以当天开始前已安排的任务为分母，主动改期和新增单独展示。至少积累 7 个已结束的有效计划日后，Today 才依据最近最多 14 日给出容量建议，不因单日低完成率作判断，也不会自动改动任务。
- **外观**：在应用设置中选择跟随系统、浅色或深色。

## 数据与备份

默认数据库在 `~/Library/Application Support/Dayline/`。应用菜单中的「打开数据文件夹」可定位该目录。正常编辑自动保存；退出再打开后继续使用原数据。不要在应用运行时手工替换或删除数据库、WAL 或 SHM 文件。

侧边栏底部「…」菜单提供：

1. **导出备份…**：导出 schemaVersion=2 的 JSON，包含领域、目标、任务、重复关联、Ideas 和计划历史。
2. **从备份恢复…**：支持 v1 / v2 JSON；确认后完整替换当前数据，并先自动保存恢复前 JSON。恢复旧版 v1 备份会清空当前 Ideas 和历史，再为导入任务建立当下基线；此操作不是合并，不能通过普通撤销恢复。

恢复会先验证版本、字段、ID、关联与目标层级，验证失败不会替换现有数据。升级前会用 SQLite 在线备份生成同目录的 `Dayline.store.before-v1.1.sqlite` 独立快照，包含已提交 WAL 内容；另有每日 JSON 与恢复前 JSON 自动备份。v1.1 仅增加模型，保留原有实体结构；真实 v1 SQLite 迁移及 v1 / v2 JSON 兼容已通过隔离测试。

历史从升级或导入时的实际观察开始，不从任务创建时间推测过去计划；过期基线不构成历史，升级当天的不完整基线不进入建议样本。事件保留记录时的日期与时区，重复任务按独立实例统计。备份是可读明文；没有云端同步或加密备份，重要数据仍应保留独立副本。

## 验证

```bash
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
scripts/test-native.sh  # 原有 SwiftData 规则与进程持久化
scripts/test-v11.sh     # Ideas、历史、迁移、备份与末次编辑持久化
scripts/test-planning.sh # 纯计划聚合与容量建议
scripts/test-export.sh  # 导出格式、分页及边界
scripts/verify.sh       # 原生断言、可用时 XCTest、debug 应用构建
swift test --scratch-path "$HOME/Library/Caches/DaylineSwiftPMBuild"
```

XCTest 与原生断言使用同一组规则检查。原生测试还启动两个独立进程，分别写入和读取临时磁盘数据库，验证真正的进程重启持久化；不会修改个人正式数据库。测试范围包括今天的日期合并、逾期、跨夏令时边界、收件箱、目标删除、重复去重、备份往返与非法备份拒绝。

v1.1 已执行原生规则 **17/17**、集成检查 **12/12**、计划分析 **12/12**，导出检查全部通过。release 构建、签名、安装和真实启动通过。真实界面验证了 Ideas 创建、中文编辑、置顶、归档、搜索、转任务、多选导出与重启保留，以及浅深色、Today 完成/撤销、近期计划和目标页面。已通过原生文件夹面板导出单日 PDF / Markdown、两条灵感合并 PDF / PNG、灵感分别 PNG、七天分别 PNG 和合并长图；三种格式的完整批量组合另由原生导出检查覆盖。

本地导出样例在 `output/v1.1-exports/`，其中 `GUI/` 为隔离 QA 界面生成的文件。中文长篇 PDF 共 12 页，已查看首页、中间页、末页并验证末尾内容；Markdown 与 PNG 已读取、打开检查。`output/` 不纳入 Git。

执行结果、功能矩阵与仍需人工验证的项目见 [Documentation/QA.md](Documentation/QA.md)。

## 版本管理

源代码在私人仓库 [dushiye/Dayline](https://github.com/dushiye/Dayline)。稳定分支是 `main`，v1.1.0 的基线标签是 `v1.1.0-baseline`。Cursor 与 Codex 共同遵守 [AGENTS.md](AGENTS.md)。

日常开发、提交、推送、打版本、恢复旧代码，以及代码回退与 SwiftData 数据恢复的区别，见 [Documentation/Git.md](Documentation/Git.md)。检出旧代码不会回退 `~/Library/Application Support/Dayline/` 里的正式数据库。

`v1.1.0-baseline` 记录的 42/42 XCTest 是 2026-10-25 已完成的验收，建立仓库时没有重新运行测试。v1.1.1 发布前于 2026-10-26 实际复跑 XCTest，44/44 通过。发布记录见 [Documentation/QA.md](Documentation/QA.md)。

## 范围与限制

这是本地单用户 macOS 应用。未提供通知提醒、日历/提醒事项集成、自然语言日期解析、月度或自定义重复、移动端、番茄钟、附件、领域增删以及多窗口协作。重复规则目前只包括不重复、每日和每周；它由完成动作触发，不是后台定时器。删除任务为不可撤销操作，界面会要求确认。

## 后续迭代

- 补齐最小窗口尺寸、完整键盘操作与 VoiceOver 验收，完善拖动排序反馈。
- 补充长时间跨午夜驻留与旅行场景的图形验收；跨时区事件归属已通过上海/洛杉矶切换集成测试。
- 扩展磁盘故障注入及更大数据量的备份、迁移回归。

这些是后续计划，不属于当前已交付功能。

## 实际截图

- [v1.1 灵感浅色](Documentation/Screenshots/v11-ideas-light.png)
- [v1.1 灵感深色](Documentation/Screenshots/v11-ideas-dark.png)
- [v1.1 统一导出中心](Documentation/Screenshots/v11-export.png)
- [v1.1 正式安装版空工作区](Documentation/Screenshots/v11-installed-empty.png)
- [Today 浅色](Documentation/Screenshots/02-today-light-final.png)
- [Today 深色](Documentation/Screenshots/05-today-dark-final.png)
- [正式首次启动空状态](Documentation/Screenshots/06-first-launch-empty.png)

以上均为实际运行窗口。Ideas 截图与导出样例使用隔离 QA 数据；正式数据库未混入演示内容。
