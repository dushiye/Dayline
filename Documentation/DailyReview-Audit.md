# Daily Review 工程审计

日期：2026-10-28
基线：`main` / `origin/main` 均为 `62da11b`（tag `v1.2.1`）
开发分支：`feat/daily-review`

## 当前结构

- macOS 与实验性 iOS 应用共用 `Packages/DaylineCore` 和 `Packages/DaylineData`。Mac UI 位于 `Sources/Dayline`，iOS UI 位于 `Sources/DaylineIOS`；两端均明确使用本地 SwiftData，`cloudKitDatabase` 为 `.none`。
- `DaylineData` 当前注册 5 个持久模型：`Area`、`Goal`、`DayTask`、`Idea`、`PlanningEventEntity`。模型以手写 `PersistentModel` schema 保持 Command Line Tools 与 Xcode 兼容。
- `DaylineStore` 使用同名 `ModelConfiguration("Dayline")`；Mac 默认库仍是 `~/Library/Application Support/Dayline/Dayline.store`。测试通过内存容器、临时文件或 Xcode scheme 的 `DAYLINE_XCTEST_MODE=1` 隔离。
- JSON 备份实际版本为 `schemaVersion=2`。v1 不包含 Ideas/计划历史；v2 包含它们。恢复为先完整解码和验证，再写恢复前快照，最后在事务内执行整库替换。
- `Documentation/iPhone-CloudKit-Architecture.md` 不存在；等价现状记录在 `Documentation/PhaseA-SharedCore.md` 与 `Documentation/PhaseB-iOS.md`。当前没有 CloudKit，也不应在本功能中启用。

## 可复用组件

- `DaylineDateField` 与 `DaylineDateSelection` 可用于历史日期选择和稳定的日历日导航。
- Ideas 的分栏、长文本编辑、可见错误状态和即时持久化行为可作为交互参考；Daily Review 需要独立防抖草稿，以避免每次击键都保存。
- `DaylineDesign`、`QuietEmptyState` 与侧边栏导航样式可直接延续现有视觉语言。
- `PlanningAnalysis` 已基于捕获时区的历史事件提供只读计划统计；回顾页可以只显示当天的简要统计，不重建历史任务状态。
- `ExportDocument` / `DaylineExporter` 已提供统一的 Markdown、PDF、PNG 文档渲染与安全写入。Daily Review 可新增同一数据快照到该流程，P1 优先接入 Markdown/PDF。
- `DaylineSafetyBackup` 已使用 SQLite online backup 生成独立单文件快照，可扩展新的“加入 DailyReview 前”快照名称。

## 必须变更的文件

- `Packages/DaylineData/Sources/DaylineData/`：新增 `DailyReview` 与记录类型；把模型加入 schema；增加查询、幂等 upsert、删除、刷新与备份恢复。
- `Backup.swift`：升级 JSON 到 v3；v1/v2 缺少回顾时兼容解码；校验日键、时区、唯一日期与稳定 ID。
- `DaylineSafetyBackup.swift`：保留原 v1.1 快照，并增加本次 schema 升级前的独立快照。
- `Sources/Dayline/Views/DaylineDailyReviewView.swift`：日期导航、三问与自由记录、空状态、删除确认、防抖自动保存和失败提示。
- `DaylineRootView.swift`：侧边栏“回顾”、Today 轻入口、旧备份会清除回顾的恢复提示，以及页面导航。
- `DaylineApp.swift`：正常退出/进入后台前触发回顾草稿刷新所需的通知；不得替换正式 App。
- `ExportDocument.swift` / `DaylineExportCenter.swift`：P1 复用现有导出中心增加回顾 Markdown/PDF。
- `Tests/`、`scripts/generate-project.py`、`README*` 与 `Documentation/QA.md`：加入迁移、JSON、日期身份、持久化、Mac/iOS 构建和实际执行记录。

## 数据迁移风险

1. **新增模型**：属于增量 schema，但必须用 `Tests/Fixtures/v1.store` 和当前 v1.1/v1.2 合成库的副本实际打开、写入、重开；不能把空库视为成功。
2. **升级前快照**：现有快照文件固定为 `.before-v1.1.sqlite`，已存在时不会为本次模型变化再保存一次。本次需新增不同名称的 SQLite online snapshot，且失败时停止打开而不是重建数据库。
3. **日历日身份**：不能只存 UTC 时间。采用唯一 `dayKey`（`yyyy-MM-dd`）与创建时 `timeZoneID`；编辑与旅行不会重算已有身份。日期切换以日键做算术并测试上海、洛杉矶和 DST。
4. **整库恢复**：v3 必须包含回顾；恢复 v1/v2 时按现有“完整替换”语义清空当前回顾，并在 UI 明确提示。无效/重复日期必须在任何写入前拒绝。
5. **自动备份缺口**：当前 `Dayline-Auto-yyyy-MM-dd.json` 使用“不覆盖”，当天首次启动后新增的晚间回顾不会进入该文件。方案是保留首份日备份，同时在回顾完成/后台或退出时写入带时间与唯一后缀的追加式安全快照，不能覆盖唯一文件。
6. **测试夹具访问**：Mac application-hosted XCTest 当前在 `Data(contentsOf: #filePath...)` 读取桌面仓库夹具时被系统文件访问层阻塞。需要把夹具定位改为测试 bundle 或先复制到缓存，再运行完整 Xcode 测试。

## 修改前测试基线

- `swift test --package-path Packages/DaylineCore`：6/6 通过。
- 根包 `swift test`：执行 47 项，46 通过、1 项按设计跳过（只适用于 Xcode 应用宿主），0 失败。
- `DaylineIOS` generic iOS Simulator Debug build：`BUILD SUCCEEDED`。
- Mac Xcode 测试：前 7 项通过，随后在读取仓库内 v1 JSON 夹具时阻塞；已中止且没有访问正式数据库。该基础设施问题会在实现阶段修复后重新执行完整套件。
- 基线日志：`build/daily-review-baseline-core.log`、`build/daily-review-baseline-swiftpm.log`、`build/daily-review-baseline-ios.log`、`build/daily-review-baseline-mac.log`（本地构建产物，不提交）。

## 实施路径

1. 新增共享 `DailyReview` 模型与稳定日键工具；扩展容器和新的升级前快照。
2. 扩展 `DaylineStore`，保证每个日键最多一条、空草稿不落库、保存失败回滚且 UI 草稿保留。
3. 将 JSON 升级为 v3，兼容恢复 v1/v2，并为旧备份清除回顾提供明确提示。
4. 实现 Mac 回顾页、防抖自动保存、历史导航、删除和 Today 轻入口；只读计划摘要复用现有历史分析。
5. 低风险复用导出中心，加入单日/多日 Markdown 与 PDF。
6. 增加隔离数据库、迁移、时区/DST、备份回滚、自动备份和 iOS 共用模型测试；修复 Xcode 夹具定位。
7. 完成 Mac Debug/Release、完整 XCTest、iOS build/test 和隔离 QA GUI 验收；更新文档、提交并推送功能分支，不合并 `main`、不安装正式 App。

审计结论：现有架构支持安全的增量模型与 v3 JSON 升级，没有必须停止开发的迁移风险。关键条件是新增独立升级前快照、在隔离旧库副本上验证、保持整库恢复原子性，并彻底避免正式数据库与已安装 App。

## 实施结果

- 已采用第六个共享 SwiftData 模型 `DailyReview`，以唯一 `dayKey` 和确定性 UUID 保证每个日历日最多一份，并保留创建时 `timeZoneID`。
- Mac 已加入回顾页、三项核心问题、自由记录、日期导航、历史入口、删除确认、700 ms 防抖自动保存、失败草稿保留、Today 轻入口和只读计划历史摘要。
- JSON 已升级到 v3；v1/v2 缺少回顾时正常解码，恢复仍为整库替换。UI 会明确提示旧备份将清除当前回顾。
- 复用了现有导出中心和排版器，提供单日/多日、合并/分别的 PDF、Markdown 和 PNG；没有新增第二套渲染架构。
- 旧 v1 SQLite 与当前五模型合成库均已在临时副本迁移并重开，旧实体数量与业务 ID 保持不变；Mac 54/54 XCTest、iOS 7/7 XCTest 和四套旧规则脚本均通过。完整命令与限制见 `Documentation/QA.md`。
