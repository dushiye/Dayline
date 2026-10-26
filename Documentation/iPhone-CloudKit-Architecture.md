# Dayline iPhone 与 Mac 双向同步架构

状态：架构与隔离验证。不是实现，不改正式库，不发布新版本。

日期：2026-10-26。基线是已发布的 macOS **1.1.1（build 3）**，`main` 提交 `16a5a10c702ce985d7ef4b8a5c4813dfe4ff8453`。后续实现放在独立 Git 分支，不直接改 `main`。

## 结论

当前 SwiftData 存储可以继续做本机数据库，但不能原样打开 CloudKit。

必须先改的是同步身份，不是界面：

- 五个模型的 `id` 都标了 `Schema.Attribute(.unique)`。CloudKit 不支持唯一约束。
- `PlanningEventEntity.payload` 是非可选 `Data`，schema 默认值是 `nil`。CloudKit 要求属性可选，或在模型上带默认值。
- 计划事件的 `sequence` 和 `PlanningEventRecord.id` 都是本机生成的。两台设备会各写一条，历史无法去重。
- 重复任务的下一次身份已经用 `stableUUID` 固定；这个做法要保留，并扩到计划事件。
- App 现在关闭沙盒、使用 ad-hoc 签名、没有 iCloud entitlement。正式同步前要有 Apple Developer 账号、开发证书、App Sandbox、iCloud/CloudKit 和远程通知。打开沙盒会改变数据目录，必须先把现有库复制进容器并核对条数，再考虑上传。

在此之前，`ModelConfiguration` 继续使用 `cloudKitDatabase: .none`。JSON 备份仍是用户可带走的副本，iCloud 不是唯一备份。

## 1. 现有 macOS 数据审计

### 存储

`DaylineStore.makeContainer` 使用这五个类：

`Area`、`Goal`、`DayTask`、`Idea`、`PlanningEventEntity`。

配置名是 `"Dayline"`。未传入 URL 时，路径是：

`~/Library/Application Support/Dayline/Dayline.store`

显式关闭 CloudKit。`ModelContext.autosaveEnabled = false`，保存走 `commit()`。启动时如果领域、目标和任务都为空，会插入 `DaylineSeeds.areas` 里三个固定 UUID 的领域。

测试和 QA 只允许内存库、临时目录或 `--qa-store`。正式库不参与同步实验。

### 模型

没有 SwiftData relationship。领域、目标和任务用可选 UUID 互指。删除目标时，代码把相关任务和子目标的外键清空。这个形状对同步比对象关系更合适：CloudKit 不保证关系变更原子到达，而 UUID 可以晚到后再接上。

| 模型 | 关键字段 | 同步含义 |
| --- | --- | --- |
| `Area` | `id` 唯一；名称、符号、颜色、排序有默认值 | 三个种子 UUID 必须两端相同 |
| `Goal` | `id` 唯一；`targetDate`、`areaID`、`parentGoalID` 可选 | 日期仍是绝对 `Date`，展示时要保留日历日 |
| `DayTask` | `id` 唯一；计划日、截止日、重复来源和后继都是可选 UUID 或 `Date` | 后继 ID 已由 `stableUUID` 决定 |
| `Idea` | `id` 唯一；正文是 `String` | 长正文以后可能超过 CloudKit 记录上限 |
| `PlanningEventEntity` | `id` 唯一；`payload: Data`；`sequence: Int` | 事件内容封在 JSON 里，序号只在本机递增 |

`PlanningEventRecord` 本身已经有 `taskID`、`kind`、`dayKey`、`newDayKey`、`timeZoneID`。这些字段适合做去重，但现在每次 `historyEvent` 都 `UUID()`，再把整条记录编码进 `payload`。

### 迁移与备份

没有 `VersionedSchema` 或 `SchemaMigrationPlan`。v1.1 只增加 `Idea` 和 `PlanningEventEntity`。打开已有磁盘库前，`DaylineSafetyBackup.beforeUpgrade` 把库复制为同目录的 `Dayline.store.before-v1.1.sqlite`；目标已存在则跳过，失败不删原库。

JSON 备份 `schemaVersion` 为 2，能读 v1 和 v2。校验失败不替换。恢复前写 `Before-Restore-<UUID>.json`。每日 `Dayline-Auto-yyyy-MM-dd.json` 同名不覆盖。这条链路在同步之后仍然保留，并在第一次上传前强制再导出一份。

### 已有的正确身份

`makeSuccessorIfNeeded` 用系列 ID 加发生日生成 `stableUUID`。同一系列、同一天不会再建第二条后继。同步设计沿用这个键，不改用随机 UUID。

`historyDay` 用写入时的 `TimeZone.current` 生成 `yyyy-MM-dd`。计划历史因此不会因为后来改时区而被重算。任务上的 `scheduledDate` / `dueDate` 仍是绝对时间，换台时区不同的设备展示时仍可能跨日。共享模型要补日历日，而不是只同步 `Date`。

## 2. CloudKit 兼容性

官方要求来自 SwiftData 的跨设备同步文档：

- iCloud capability 里启用 CloudKit，并指定容器。需要有管理权限的 Apple Developer 账号。
- Background Modes 启用 Remote notifications。SwiftData 靠静默推送收变更。
- 不能使用唯一约束。CloudKit 不能并发强制 Unique。
- 关系必须可选，并且能确定反向关系。不支持 Deny 删除规则。
- 属性必须可选，或有默认值。
- 开发期先在 Development 环境初始化 schema。发布前才提升到 Production。Production schema 只能增加，不能删除类型或改已有字段的含义。

2026-10-26 在 Xcode 27.1 上做了隔离探测。程序只写入系统临时目录，容器名使用 `iCloud.app.dayline.probe`，没有打开 `~/Library/Application Support/Dayline`。

- 字段都有默认值、没有唯一约束、外键可选的模型：`CONTAINER_CREATED`。
- `#Unique` 的 `id`：Core Data `NSCocoaErrorDomain` 134060。错误写明非可选且无默认值，并且 CloudKit 不支持 `UniqueItem.id` 唯一约束。随后命令行进程因没有 bundle identifier 在 PushKit 清理时崩溃；模式错误本身已经由 134060 给出。
- 非可选、声明处没有默认值的 `Data`：同样是 134060，点名 `payload`。初始化器里赋 `Data()` 不够。

因此当前五个模型不能作为 CloudKit store 打开。去掉 `id` 的唯一约束、给 `id` 和 `payload` 默认值之后，存储层才具备打开同步配置的条件。业务去重改由稳定 ID 和导入时合并完成。

本机 `security find-identity -p codesigning` 没有可用签名身份。工程 `CODE_SIGN_IDENTITY` 是 `"-"`，没有 `DEVELOPMENT_TEAM`，没有 entitlements，`ENABLE_APP_SANDBOX = NO`。这台机器现在不能创建或访问真实 CloudKit 容器。探测只证明了模式规则。

## 3. 必须调整的模型

这些调整放到新的 schema 版本，先在数据库副本上迁移。当前 1.1.1 的正式库保持 `cloudKitDatabase: .none`。

1. 去掉 `Area`、`Goal`、`DayTask`、`Idea`、`PlanningEventEntity` 的 `Schema.Attribute(.unique)`。`id` 仍是业务主键，默认 `UUID()`。
2. `PlanningEventEntity.payload` 改为有默认值的 `Data`，或改成可选。更合适的做法是把 `PlanningEventRecord` 的字段拆成列：`taskID`、`kindRaw`、`occurredAt`、`dayKey`、`newDayKey`、`timeZoneID`。这样冲突和去重不用解开 JSON。旧 `payload` 只在迁移时读取。
3. `sequence` 降为本机辅助排序，不作为跨设备身份。全局顺序使用 `(occurredAt, id)`。
4. 在 `DayTask` 上增加可选 `scheduledDayKey`、`dueDayKey`、`dayTimeZoneID`。选择器保存时同时写绝对时间和日历日。展示和重复身份优先用日历日。
5. 计划事件 ID 改为 `stableUUID(taskID|kind|dayKey|newDayKey)` 这一类确定性键，而不是 `UUID()`。完成/重开若同一任务同一天只保留一条有效状态，键里包含 kind 和 dayKey。需要保留多次往返时，把键定义为「当前未关闭的那一次」，由导入端按任务合并，不让两台设备各插入一条随机记录。
6. 增加可选 `deletedAt`。第一版同步不把「硬删除 CKRecord」当作唯一删除信号。删除任务仍写 `deleted` 事件，同时标记 `deletedAt`，其他设备据此隐藏。JSON 备份照样导出这些字段。
7. 增加 `updatedAt`。CloudKit 对同一记录的字段是后写覆盖。用户可见对象用 `updatedAt` 决定展示；计划事件是追加日志，不互相覆盖。

不把 UUID 外键改成 SwiftData relationship。那样会引入反向关系和删除规则，而现有备份、测试和删除语义都建立在可空 UUID 上。同步到达顺序不定时，UUID 可以暂时悬空，界面显示为未关联，这和现在「目标已不存在就解除关联」一致。

`Idea.body` 若变长，超过 CloudKit 单记录约 1MB 的部分要标成外部存储。第一版可限制正文长度，超限仍允许本地保存，并在同步状态里说明未上传。

## 4. 账号、签名和容器

实施同步前需要：

1. 加入 Apple Developer Program，并在本机安装 Apple Development 证书。当前没有可用的 codesigning identity。
2. App ID `app.dayline.mac` 保持不变。iPhone 使用新的 `app.dayline.ios`。两者加入同一个 App Group 不是必须的；必须共享的是 CloudKit 容器。
3. 容器标识建议 `iCloud.app.dayline`。不要用 `iCloud.app.dayline.mac`，否则 iPhone 只能做客户，容易和 Mac 专用容器绑死。
4. 两个 target 都启用 iCloud + CloudKit，选中该容器；Background Modes 打开 Remote notifications。
5. Mac 要使用 iCloud，就打开 App Sandbox，并加上 iCloud entitlement。沙盒打开后，默认 Application Support 会落到 `~/Library/Containers/app.dayline.mac/Data/...`，不再是现在的 `~/Library/Application Support/Dayline/`。
6. 先在 Development 环境由带开发签名的构建初始化 schema。确认双设备可用后，才把 schema 提升到 Production。提升后只能加字段。

未完成以上步骤时，不把 `cloudKitDatabase` 改成 `.automatic` 或 `.private`。

## 5. 共享代码和目录

能共享的是纯 Swift 和与 AppKit 无关的 SwiftUI：

- 模型、`DaylineDates`、`DaylineDateSelection`、`PlanningAnalysis`、`DaylineBackup`、`DaylineStore` 的校验、重复任务和历史规则。
- `DaylineDatePicker`。它没有 AppKit 依赖。
- 三个种子领域的 UUID。

不能直接共享的是：

- `DaylineApp`、窗口、菜单、导出里的 AppKit 面板、`DaylineDesign` 里的 `NSColor`。
- Mac 的 `NavigationSplitView` 尺寸和设置窗口。iPhone 用 tab。

建议目录，在单独分支里拆，不在本文件落地：

```text
Dayline/
  Packages/DaylineCore/Sources/DaylineCore/
  Apps/DaylineMac/          # 现有 macOS target 逐步改到这里
  Apps/DaylineIOS/
  Documentation/
```

第一刀只搬不改行为：`DaylineCore` 仍使用 `cloudKitDatabase: .none`，现有 44 项测试继续指向它。Mac 界面留在原来的 target。iPhone target 等模型调整和副本迁移通过后再加。

## 6. iPhone 界面

一个 tab，五项，和 Mac 侧边栏同一套数据：

| Tab | 内容 | 和 Mac 的对应 |
| --- | --- | --- |
| 今天 | 计划日或截止日是今天的任务，逾期和未完成的过去计划分开 | `DaylineDestination.today` |
| 即将到来 | 七天，按日历日分组 | upcoming |
| 收件箱 | 无领域、无计划日、无目标的任务 | inbox |
| 目标 | 长期目标、进度、目标日、关联任务 | goals |
| 灵感 | 列表、置顶、归档、转任务 | ideas |

任务和目标编辑用 sheet。日期使用共享的 `DaylineDateField`。iPhone 不先做 Mac 的 PDF/PNG 导出中心；备份入口保留「导出 JSON / 从 JSON 恢复」。

空状态和 Mac 文案可以共用。不在 iPhone 上提供「试用示例内容」自动写入，避免和同步下来的真实数据混在一起。

## 7. 双向同步

使用用户的 iCloud 私人数据库。不做公共库，不做自建账号，第一版不做共享给其他 Apple ID。

本地始终可写。同步是后台镜像：没网时保存进本地 store，恢复网络后由 SwiftData / `NSPersistentCloudKitContainer` 上传和下载。界面不阻塞在网络上。

处理远程变更时不能再走「本机 diff 然后补历史」。`establishHistoryBaseline` 和 `recordTaskChanges` 只对用户刚刚在这台设备上做的编辑运行。从 CloudKit 拉下来的任务和事件标记为已同步，刷新列表即可。否则每台新设备都会把已有任务再写成一条 baseline。

### 冲突

- 任务、目标、灵感、领域：同一 `id` 的记录由 CloudKit 按字段后写覆盖。`updatedAt` 用于发现异常，不自己再做一套平行数据库。
- 计划事件：只追加。身份是确定性 UUID。两端写出同一个键时，CloudKit 看到的是同一条记录，而不是两条历史。
- 重复任务：继续用 `来源 ID + 发生日` 的 `stableUUID`。导入时如果 ID 已存在，只补 `recurrenceSuccessorID`，不插入第二条。
- 删除：写 `deletedAt` 和 `deleted` 事件。其他设备隐藏该任务。恢复是清空 `deletedAt` 并写 `reopened` 或单独的恢复事件。JSON 恢复仍是整库替换，替换前照旧写 `Before-Restore` 备份。

### 时区与跨午夜

选择器已经把选中日存成本机当天零点。同步后再存：

- `scheduledDate` / `dueDate`：绝对时间，给排序和提醒留用。
- `scheduledDayKey` / `dueDayKey`：`yyyy-MM-dd`。
- `dayTimeZoneID`：写入时的时区。

今天、即将到来、逾期和重复后继优先比较 dayKey。不因为用户飞到另一个时区就把昨天的计划改写到今天。这和现有 `recordTaskChanges` 的注释一致，只是把结论放进任务记录，而不只放进历史 payload。

### 首次同步和迁移

顺序固定，不能颠倒：

1. Mac 仍用未开沙盒的 1.1.1。用户导出一份 schemaVersion 2 JSON。校验通过才继续。
2. 在副本上做 schema 升级：去掉唯一约束、补默认值、展开事件字段、补 dayKey、把已有事件 ID 按确定性规则重写并去重。用临时目录，不打开正式库。
3. 打开沙盒前，把升级后的副本复制到容器内的 Application Support。启动后比对领域、目标、任务、灵感、事件条数和 ID 集合。不一致就停止，正式库仍在旧路径。
4. 沙盒版先以 `cloudKitDatabase: .none` 运行一个版本，确认日常编辑和 JSON 备份正常。
5. 用户明确选择「用 iCloud 同步」后，才把配置改为私人 CloudKit 容器。上传的是容器内那份已核对的库。
6. iPhone 首次启动不插入示例，也不在同步完成前插入第二套种子领域。若本地还没有领域，先等待第一次下载；只有确认账户下没有 Dayline 数据时，才插入与 Mac 相同的三个领域 UUID。
7. 下载完成后按业务 UUID 合并重复领域和重复事件。

旧的未沙盒目录保留只读，直到用户确认新版本可用。不自动删除 `Dayline.store`、WAL、SHM、`before-v1.1.sqlite` 或 `Automatic Backups/`。

## 8. 备份

每次开启同步前导出 schemaVersion 2 或更新后的 JSON。恢复 JSON 仍是整库替换，不经过 CloudKit 的字段合并。恢复成功后，本地库成为新的同步源；不能在恢复完成前让旧的云端记录再写回来。实现时先暂停同步、恢复、核对、再恢复同步。

每日自动 JSON 和恢复前备份保持现在的文件名规则。云端副本丢失或账号退出时，用户仍能用 JSON 和 `before-v1.1.sqlite` 回到本机。

## 9. 分阶段路线

| 阶段 | 分支上做什么 | 完成标准 | 不做什么 |
| --- | --- | --- | --- |
| A | 抽出 `DaylineCore`，Mac 改为依赖它 | 44 项测试通过，正式库路径和 CloudKit 关闭不变 | 不改 schema，不开沙盒 |
| B | 在副本上做同步 schema，保留 JSON v2 读取，写入新版本 | 旧夹具 `v1.store` 和 v2 JSON 仍能迁到新 schema；事件 ID 稳定 | 不上传，不碰正式库 |
| C | 沙盒路径迁移工具，只处理副本和测试容器 | 条数和 ID 一致；失败时旧目录完整 | 不启用 CloudKit |
| D | 配置签名、entitlement、Development 容器 | 测试 Apple ID 上，两台模拟设备用假数据同步 | 不提升 Production schema |
| E | iPhone 五个 tab 和共享日期选择器 | 离线可编辑；再联网后不产生第二条后继、不重复 baseline | 不做导出中心 |
| F | 用户可选的同步开关 | 用副本演练首次上传；JSON 备份可独立恢复 | 不强制现有用户开启 |

每阶段独立分支，从当时的 `main` 拉出，测试通过再合并。未验证的提交不打稳定标签。

## 10. 测试

隔离环境只使用内存库、`temporaryDirectory` 或 `--qa-store` 指向临时目录。

必须有的用例：

- 去掉唯一约束后，同一 `id` 的第二次插入由应用层拒绝，而不是依赖 Core Data unique。
- 两台逻辑设备完成同一重复任务，只出现一个后继 ID。
- 两台设备对同一任务写入完成事件，确定性 ID 只保留一条。
- 新设备下载已有任务后，不新增 baseline。
- 上海写入的 dayKey，在洛杉矶打开仍是原来的日历日。
- 跨午夜和夏令时：dayKey 不跟着绝对时间的 23/25 小时漂移。
- 删除后再同步，另一端隐藏；JSON 恢复能把该任务按备份内容放回。
- 沙盒复制前后 ID 集合相同。复制失败时源文件哈希不变。
- 正式库路径不在测试进程打开的文件列表里。

本阶段的 Xcode 27.1 探测只覆盖了 CloudKit 模式检查，没有账号，也没有上传。

## 11. 风险

| 风险 | 后果 | 约束 |
| --- | --- | --- |
| 打开沙盒后直接启动 | 应用看到空库并可能再次播种 | 先复制、核对，再切换路径 |
| 保留 `.unique` 就打开 CloudKit | store 无法加载，应用打不开 | 同步配置和约束一起改，先在副本上做 |
| 随机事件 ID | 历史和完成次数翻倍 | 确定性 ID，远程应用不重新推导 |
| `sequence` 当全局顺序 | 两端序号冲突，排序抖动 | 用时间和 ID 排序 |
| Production schema 过早提升 | 字段不能再改 | Development 完成双设备测试后再提升 |
| 把 iCloud 当备份 | 账号或同步错误会连备份一起丢 | JSON 和 sqlite 快照继续写在本机 |
| 在本机没有开发证书时改正式签名 | 现有 ad-hoc 安装版可能打不开 | 证书就绪前不替换 `~/Applications/Dayline.app` |

## 12. 本阶段没有做的事

没有改模型、容器、签名、沙盒或正式库。没有创建 iPhone target，没有推送这个文档分支。探测程序留在系统临时目录，不进入仓库。
