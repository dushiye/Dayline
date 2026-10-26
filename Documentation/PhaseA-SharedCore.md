# Phase A：共享核心与数据兼容性

日期：2026-10-26。分支 `feat/shared-core`，从 `main` 的 v1.1.1（`16a5a10`）拉出。没有启用 CloudKit，没有打开正式库，没有替换 `~/Applications/Dayline.app`。`ModelConfiguration` 仍是 `cloudKitDatabase: .none`，Sandbox 仍关闭，版本号仍是 1.1.1（build 3）。

## 模型留在 Mac target

五个 `PersistentModel`（Area、Goal、DayTask、Idea、PlanningEventEntity）仍在 `Sources/Dayline/Models/`。

隔离实验在 `/tmp/Dayline-ModuleMove`，没有使用正式库：两个 Swift Package 各放一个字段相同的 `@Model Note`。ModA 写入临时库后，ModB 读到 1 条，标题为 `module-move`。持久化 URI 都是 `x-coredata://45FF58CA-99B4-48BB-99C9-23ABAEF822FE/Note/p1`。`Z_METADATA` 里的实体名是 `Note`，不带模块前缀。

这只证明简单、字段一致的 `@Model` 可以换模块打开。Dayline 的手写 schema、唯一约束和 `payload` 没有做整组往返，所以本阶段不搬迁模型。

## 共享模块

`Packages/DaylineCore`（macOS 14 / iOS 17）包含：

- `DomainEnums.swift`：目标、优先级、重复规则
- `DaylineCalendar.swift`：日期网格与计划日计算
- `DaylineIdentity.swift`：重复后继 ID、计划事件的确定性身份、业务 UUID 与持久化 ID 的合并分类
- `PlanningAnalysis.swift`：计划分析

Mac app 通过本地 Swift Package 链接它。备份 JSON、SwiftData 读写、安全快照、界面和导出仍在 Mac target。`DaylineStore.historyEvent` 仍给历史事件分配随机 UUID，因此已有历史记录的字节不会因为这次抽取而改变。确定性的 `planningEventID` 只作为后续同步要接入的身份规则，还没有写进正式保存路径。

## 三种身份

- 业务 UUID：`DayTask.id`、`PlanningEventRecord.id`，以及由源任务和日历日算出的后继 ID。
- SwiftData `PersistentIdentifier`：某个库里的某一行。两个库可以保存同一个业务 UUID，但持久化 ID 不同。
- CloudKit `CKRecord.ID`：本阶段没有创建。相同业务 UUID 不会自动变成同一个 CloudKit 记录。

两台设备的模拟使用临时目录里的两个库，用备份把同一条源任务放到两边，再分别完成。后继的业务 UUID 相同，持久化 ID 不同。各自产生的完成历史 ID 也不同；把另一台设备的历史 ID 再导入时，合并函数把它当成新记录，而不是已经存储的同一条。只有事件 ID 本身相同，才会判定为重复导入。缺了中间一次重新打开时，代际不同的完成 ID 被标成冲突，而不是静默合并。

删除后从备份恢复，业务 UUID 还在，但恢复出来的是新的持久化行。
