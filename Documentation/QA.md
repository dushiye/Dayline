# Dayline 验证记录

本文件区分已执行结果、源码检查与尚未执行的验收。规则测试由质量代理执行，最终构建与真实界面结果由主集成代理提供。未勾选的项目不能视为已通过。

Git 标签 `v1.1.0-baseline` 引用的是本节已有验收，不是打标签时重新执行的测试。建立仓库时没有再次运行 XCTest，也没有启动正式数据库。原始日志留在本地 `build/`，不纳入 Git。后续提交若声称测试通过，必须写明当次实际运行的命令和结果。

## Daily Review 功能分支（2026-10-28）

分支：`feat/daily-review`，基线 `main` / `origin/main` 为 `62da11b`（tag `v1.2.1`）。本节验证的是未发布功能分支；没有安装、替换或启动正式 Dayline.app，也没有访问 `~/Library/Application Support/Dayline/`。

环境：macOS 27.0（26A428），Xcode 27.1（27A9275），Developer Directory `/Applications/Xcode.app/Contents/Developer`，Apple Swift 6.4，Mac 部署目标 14.0，实验性 iOS 部署目标 17.0。Mac Bundle Identifier 仍为 `app.dayline.mac`，CloudKit 仍关闭。

### 实际执行结果

| 检查 | 结果 |
| --- | --- |
| 根 SwiftPM | `swift test`：执行 54 项，53 通过、1 项按设计跳过（仅 Xcode 应用宿主可验证），0 失败 |
| DaylineCore | `swift test --package-path Packages/DaylineCore`：6/6 通过 |
| Mac XCTest | Xcode `Dayline` scheme，临时 DerivedData：**54/54 通过，0 失败、0 跳过**；结果包位于 `/tmp/dayline-daily-review-xcode-mac/Logs/Test/` |
| Mac 构建 | Debug 与 Release 均 **BUILD SUCCEEDED**；Release 为 arm64 + x86_64，产物只在 `/tmp/dayline-daily-review-build-*`，未安装 |
| iOS 构建 | generic iOS Simulator 的 Debug 与 Release 均 **BUILD SUCCEEDED** |
| iOS XCTest / UI Test | 隔离 Simulator：单元与布局 **7/7 通过**，既有 UI 自动化 **3/3 通过**，均为 0 失败；包含共享六模型容器与 DailyReview 持久化，并回归五个现有 Tab、任务编辑、目标与 Idea 转任务 |
| 旧原生规则 | `scripts/test-native.sh`：17/17；脚本已改为链接当前 `DaylineCore` / `DaylineData` 模块 |
| v1.1 回归 | `scripts/test-v11.sh`：12/12；Ideas、历史、v1 SQLite、v1/v2 JSON、快照与独立进程持久化均通过 |
| 计划分析 | `scripts/test-planning.sh`：12/12 |
| 导出 | `scripts/test-export.sh build/daily-review-export-samples-20261028`：全部通过；实际生成回顾合并/分别 PDF 与 Markdown，并读取 PDF 文本、页数和 Markdown UTF-8 长中文末尾；原计划/灵感 PDF、MD、PNG 回归也通过 |

主要构建命令：

```bash
xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/dayline-daily-review-build-debug build

xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/dayline-daily-review-build-release build

xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/dayline-daily-review-xcode-mac test
```

### Daily Review 覆盖

- 创建、同日幂等更新、空白新稿不生成记录、清空已保存内容不绕过删除确认、确认删除、重开持久化。
- 700 ms UI 防抖所调用的草稿提交行为；成功后清除 dirty，模拟失败时文字和 dirty 状态保留。
- 上海、洛杉矶、夏令时、闰日、跨年与编辑历史日期；日键不会随查看时区移动。
- 真实 `Tests/Fixtures/v1.store` 副本和五模型合成 v1.1 数据库的增量迁移；Areas、Goals、Tasks、Ideas、Planning Events 的数量及 ID 保留，源夹具不修改。
- JSON v1/v2 解码、v3 往返、重复日期/错误身份/损坏数据拒绝、失败恢复不写入、旧备份整库替换清除回顾。
- 每日不可覆盖备份之后的追加式回顾快照；同秒多次提交也不覆盖。
- 单日与多日回顾合并/分别导出，长中文 PDF 自动分页且末尾文本可提取，Markdown 保留标题、段落和换行。

### 数据隔离与迁移结论

全部持久化测试使用 `ModelConfiguration` 内存库、`/tmp` 临时库、测试 bundle 内的合成夹具，或 Xcode scheme 的 `DAYLINE_XCTEST_MODE=1`。加入 `DailyReview` 前，文件库会用 SQLite online backup 写独立的 `.before-daily-review.sqlite`；创建失败会停止打开，不会重建空库。测试证明现有五类实体在迁移后保留，并可新增、重开 DailyReview。

备份版本从 v2 升至 v3。v3 必须带 `dailyReviews`；v1/v2 缺少该字段时解码为空。恢复语义仍是完整替换，旧备份会清除当前回顾，确认文案已明确说明。恢复校验在事务前完成，恢复前仍写独立安全备份。

原来的 `Dayline-Auto-yyyy-MM-dd.json` 不覆盖同名文件，因此可能早于晚间回顾。功能分支保留该首份日备份，并在回顾切页、应用进入后台或正常退出时写 `Dayline-Review-时间-随机后缀.json`；自动化测试验证它包含最后文字且不会覆盖已有快照。

### 界面验收状态

已完成源码级可访问性标识、Mac Debug/Release 构建、长文本导出渲染和 iPhone 三种尺寸的既有 layout rendering test。当前会话没有可调用的 Computer Use / 屏幕捕获工具，因此**没有执行 Mac 窗口点击验收，也没有生成新的 Daily Review GUI 截图**。这两项不能标成通过。合并前仍需用 `--qa-store <临时路径>` 手工检查：浅色/深色、最小窗口、长文本、快速切换日期、输入后立即切页、退出重开、删除确认、Today 入口、回顾导出和键盘焦点。严禁用正式数据库完成这份清单。

已知限制：iOS 本轮只共享并验证新模型，没有增加第六个 Tab；没有 CloudKit；「保存选中文字为灵感」未实现；回顾页计划摘要只在已有可靠 Planning Event 日汇总时显示；没有更改正式版本号或创建 Release。

### 本机安装与正式库增量迁移（2026-10-28）

用户明确授权替换 `~/Applications/Dayline.app` 并沿用原有数据。`feat/daily-review` 已通过非快进提交 `92818ca` 合并并推送到 `origin/main`。安装使用 `DAYLINE_REPLACE_INSTALLED=yes scripts/install-macos.sh "$HOME/Applications/Dayline.app"`，脚本从当前 `main` 重新执行 Release 构建、ad-hoc 签名和 strict 验证后才移动旧 App；安装后二进制 SHA-256 与已验证构建一致。

旧应用先正常退出。新版随后从 `~/Applications/Dayline.app` 启动并持续运行，成功打开原 `Dayline.store`；新的 `Dayline.store.before-daily-review.sqlite` 升级前在线快照已存在，系统日志没有 Dayline error/fault。根据 `AGENTS.md`，代理没有读取 SQLite 内容、没有复制或替换数据库，也没有用正式库执行测试，因此没有记录或暴露用户任务正文与精确记录数。原有数据由相同 Bundle Identifier、存储目录和 `ModelConfiguration("Dayline")` 原地增量迁移；迁移失败时应用会显示数据库错误页而不会创建空库顶替。

Applications 中两个旧 App 副本在新应用稳定运行后移入废纸篓，当前 `~/Applications` 只保留一个 `Dayline.app`，避免 Spotlight 再显示旧版本。当前 App 的 Info.plist 版本仍为 1.1.1（build 3）；这次没有创建 Tag、Release 或更改签名身份。

## 日期选择器（2026-10-26）

目标日期、任务计划日期、任务截止日期和导出起止日期共用 `DaylineDateField`。弹层宽 344 pt。选中日为实心圆，今天为圆环。点选后保存为本机日历的当天零点并关闭弹层；清除会关闭任务或目标的日期开关。导出范围不提供清除。编辑器的「取消」只调用 `dismiss()`，不执行保存。

合并到 `main` 前的当次结果：

| 检查 | 已执行结果 |
| --- | --- |
| Release 构建 | Xcode 27.1，scheme `Dayline`，`platform=macOS,arch=arm64`，DerivedData 为 `~/Library/Caches/DaylineXcodeDerivedData`，配置 Release：**BUILD SUCCEEDED**。产物在 DerivedData，没有覆盖 `~/Applications/Dayline.app` |
| Xcode XCTest | **44/44 通过，0 失败**。原有 42 项全部通过；新增 `testDateGridAndTimeZoneDay` 与 `testGoalTargetDateRoundTripsOnIsolatedStore` |
| 隔离持久化 | 后一项在临时目录 `Dayline-DatePicker-<UUID>/Dayline.store` 中创建目标日期、重开、改期、清除并再次重开，不打开正式库 |
| 正式库 | 测试前后比较 `Dayline.store`、WAL、SHM、`Dayline.store.before-v1.1.sqlite` 和 `Automatic Backups/` 的大小、修改时间与 SHA-256，全部一致 |
| 界面 | 隔离库 Debug 窗口中打开目标日历（浅色、深色）和任务计划日期日历。用户已确认视觉效果。截图在 `Documentation/Screenshots/date-picker-light.png`、`date-picker-dark.png`、`date-picker-task-light.png` |

合并到 `main` 时版本号仍是 **1.1.0（build 2）**，当时还没有创建 `v1.1.1` 标签。随后的安装和发布见下一节。

## v1.1.1 发布（2026-10-26）

版本 **1.1.1（build 3）**。Bundle Identifier 仍是 `app.dayline.mac`。Release 产物为 ad-hoc 签名，`codesign --verify --deep --strict` 通过。

发布前再次执行完整 XCTest：**44/44 通过，0 失败**。在桌面目录直接跑测试时，读取 `Tests/Fixtures/v1-backup.json` 曾被文件提供程序卡住；同一份源码复制到本地磁盘后的完整套件 1.5 秒内通过。原有 42 项都在通过列表中。

安装前退出正在运行的 Dayline，并把 `~/Applications/Dayline.app` 改名为 `~/Applications/Dayline-1.1.0-build2-20261026-082850.app`。新版安装到原来的 `~/Applications/Dayline.app`。数据库目录没有移动。退出后的一致副本在 `~/Library/Application Support/Dayline/Manual-Backups/before-v1.1.1-20261026-082850/`。

启动安装版后，Today、即将到来、收件箱、目标、灵感都能打开。新建目标时打开了新日历，选中今天并显示圆环；随后点「取消」，没有保存。记录身份在升级前后一致：领域 3、目标 2、任务 4、灵感 0、计划事件 4。升级快照 `Dayline.store.before-v1.1.sqlite` 与两份自动 JSON 备份的 SHA-256 没有变化。灵感在升级前就是 0 条。

## v1.1 增量验收（2026-10-25）

版本 **1.1.0（build 2）**。本节为当前验收状态，下方 v1.0 记录完整保留作历史，旧版本的构建与图形结果不代表本轮复验。

完整 Xcode 原生开发环境已配置完成：`/Applications/Xcode.app` 为 Xcode 27.1（build 27A9275），当前 Developer Directory 是 `/Applications/Xcode.app/Contents/Developer`；许可协议与首次启动组件均已完成。`xcodebuild`、Apple Swift 6.4 与 Swift Package Manager 6.4 已实际执行。

| 检查 | 已执行结果 |
| --- | --- |
| 原有原生规则 | `scripts/test-native.sh`：17/17 |
| v1.1 集成 | `scripts/test-v11.sh`：12/12；Ideas 与事件、真实 v1 SQLite 迁移、v1 / v2 JSON 兼容、冷数据库与 live WAL 安全快照、独立进程末次编辑持久化；实际切换上海/洛杉矶时区，验证完成/重开/删除保留原计划日、主动改期采用新计划日 |
| 计划分析 | `scripts/test-planning.sh`：12/12；合成 14 日、少于 7 日不建议、7/14/30 有效日窗口、当天容量阈值、改期/删除/撤销、去重、重复实例、午夜与捕获时区、基线不伪造历史、已完成基线重开后补录计划 |
| 导出 | `scripts/test-export.sh`：全部通过；PDF / PNG / Markdown，7 天分别/合并，多条 Ideas 分别/合并，长中文、长标题、空内容、冲突、取消、无效路径、PNG 超限 |
| 产物检查 | 样本在 `output/v1.1-exports/`；用 Poppler 实际查看 PDF 首页、长灵感第 2 / 12 页以及 GUI 灵感 PDF，末尾标记完整；Markdown 内容已读取；计划与合并灵感 PNG 已打开检查中文、换行及留白 |
| Xcode Debug / Release | 使用 `Dayline.xcodeproj`、共享 `Dayline` scheme 和 macOS arm64 destination，Debug 与 Release 均 `BUILD SUCCEEDED`；DerivedData 位于 `~/Library/Caches/DaylineXcodeDerivedData` |
| Xcode XCTest | `DaylineTests` target：**42/42 通过，0 失败、0 跳过**；覆盖原规则、SwiftData 磁盘持久化、v1 迁移和 v1/v2 备份、Ideas、计划事件与 Planning Coach、PDF/Markdown/PNG 导出及测试宿主数据库隔离 |
| Swift Package Manager | `swift package describe` 正常；`swift test --scratch-path ~/Library/Caches/DaylineSwiftPMBuild` 执行 42 项，41 通过、1 项按设计跳过（仅适用于 Xcode 应用宿主的环境变量检查），0 失败 |
| 最终发布 | Xcode Release 构建、ad-hoc 签名和 strict 验证通过；安装版 `~/Applications/Dayline.app` 与 Xcode Release 产物均真实启动成功，版本 1.1.0（2） |

### Xcode 原生构建与测试（2026-10-25）

实际命令使用桌面目录之外的 DerivedData，避免 File Provider 给签名产物附加 FinderInfo：

```bash
xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" build

xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" build

xcodebuild -project Dayline.xcodeproj -scheme Dayline \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" test
```

最终源码的 XCTest result bundle：`~/Library/Caches/Dayline-XCTest-20261025-Final.xcresult`。构建与测试日志分别为 `build/xcode-debug-build.log`、`build/xcode-release-build.log`、`build/xcode-test-final-source.log`；正式数据库前后清单为 `build/xcode-test-formal-before.txt` 与 `build/xcode-test-formal-after.txt`，`diff` 结果为空。

测试数据安全：scheme 的 Test Action 明确设置 `DAYLINE_XCTEST_MODE=1`，应用宿主将数据库放入进程专属的 `/tmp/Dayline-XCTest-<pid>/Dayline.store`。最终完整 XCTest 前后对正式 `Dayline.store`、`Dayline.store-wal`、`Dayline.store-shm` 比较 SHA-256、文件大小与修改时间，全部保持一致。配置过程中曾发现 Test Action 继承 Launch Action 环境会忽略该变量；第一次 41 项运行只打开了正式 SQLite 共享内存，数据库/WAL/SHM 内容哈希均未变化，但 SHM 修改时间变化。已改为 Test Action 独立环境并加入 `testXCTestHostUsesTemporaryDatabase` 回归测试；修复后的单项和完整 42 项运行均未触碰正式数据库文件。

GUI 回归使用 Xcode Release 产物和 `build/xcode-gui-qa/Dayline.store` 隔离数据库：Today 示例任务显示正常，完成/撤销从 0/3 到 1/3 再回到 0/3，Ideas 空状态和统一 Export Center 正常。随后真实打开安装版，正式工作区、侧边栏、Today 空状态与导出入口正常；没有向正式库写入测试数据。

数据安全：仅新增持久模型，原有实体结构不变。升级前 SQLite 在线快照为 `<数据库名>.before-v1.1.sqlite`，纳入已提交 WAL 并生成独立文件；另有每日 JSON 和恢复前 JSON。v2 备份包含 Ideas 与事件；恢复 v1 会完整替换并清空当前 Ideas、历史，再按导入时刻建立基线。历史不追溯伪造升级前计划；不完整基线日不用于教练样本。事件顺序随持久序号保存。

统计口径：计划导出按 scheduledDate 优先、否则 dueDate 归入唯一日期，与 Today 的日期 OR 提醒不同。历史实际完成按发生日，原计划完成按原归属日；新增与主动改期分别统计。Today 至少需要 7 个已结束有效计划日，依据最近最多 14 日给出只读建议。导出范围最多 366 天；PNG 单边上限 16,384 像素、总面积上限 3,200 万像素，文件冲突自动加序号且不覆盖。

已完成的真实界面操作：

- [x] Ideas 新建、中文编辑、置顶、归档、搜索、转任务。
- [x] 两条 Ideas 多选。
- [x] 原生导出 sheet 的单日 PDF / Markdown 成功路径。
- [x] 多选 Ideas 首次打开导出 sheet：修复为 `sheet(item:)` 后正确显示灵感类型、所选范围与两条勾选项。
- [x] 两条灵感合并 PDF / PNG、分别导出两张 PNG，七天分别导出七张 PNG、合并导出一张长图。
- [x] 原生文件夹面板取消后提示未生成文件；不修改任务或灵感。
- [x] PNG 产物视觉检查。
- [x] release、签名、安装与真实重启：同一 QA 数据库不带 demo 重开，中文标题/正文/置顶/目标关联均保留；最终安装版正常打开正式数据库。
- [x] v1.1 浅色 / 深色窗口复验与实际截图，验收后恢复跟随系统。
- [x] Today 完成/撤销恢复 0/3；计划记录显示有效历史不足，不产生容量建议；近期计划、收件箱、目标及关联行动页面正常。

实际截图：`Screenshots/v11-ideas-light.png`、`Screenshots/v11-ideas-dark.png`、`Screenshots/v11-export.png`、`Screenshots/v11-installed-empty.png`。前三张为隔离 QA，最后一张为正式工作区。

正式数据升级审计：升级前快照与升级后逐行比较，Area 3→3、Goal 0→0、Task 0→0，原表记录一致，见 `build/v11-formal-migration.json`。含真实旧任务、目标、重复关联的数据迁移另在隔离夹具通过。正式库未加入测试数据。

真实 GUI 发现并修复两项交互问题：所选灵感首次打开 sheet 的状态传递；原生文件夹面板恢复目录时确认按钮长期禁用。后者设置独立面板标识、明确初始/上次目录、清空类型过滤并在回调关闭面板后，连续导出与取消均成功；没有强制启用系统按钮。系统云盘/离线目录的所有状态仍未穷举。

日志：`build/v11-native-tests.log`、`build/v11-integration-tests.log`、`build/v11-planning-tests.log`、`build/v11-bundle-release.log`、`build/v11-install.log`。导出检查由 ExportChecks 原生 runner 执行；可用 `scripts/test-export.sh <输出目录>` 重现。

本轮未执行：macOS 14/Intel 实机、最小窗口/完整 VoiceOver、长时间跨午夜驻留、磁盘满/写入中崩溃故障注入。Ideas 删除、v2 JSON 恢复、全部导出格式组合和规则建议阈值由 XCTest 与原生测试覆盖，未将每一组合重复点击 GUI。当前个人数据不足 7 天，因此没有在正式库伪造教练历史或建议。

非阻断提示：无 AppIntents 依赖，因此 metadata extractor 跳过；无界面的 XCTest 宿主可能输出 `com.apple.linkd.autoShortcut` 连接警告；部分 SQLite 隔离测试输出保留 flag `0x10` 的系统警告。上述提示均未造成构建或测试失败。

## v1.0 历史验收记录

## 环境与执行记录

- 机器：Apple Silicon Mac，macOS 27.0（26A428）；Apple Swift 6.3.2，Swift 5 语言模式；部署目标 macOS 14。
- 选中开发目录：`/Library/Developer/CommandLineTools`。
- 已执行 `swift -e 'import XCTest'`：失败，提示 `no such module 'XCTest'`。因此当前环境不能声称 XCTest 通过；保留 XCTest 测试供完整 Xcode 工具链使用。
- 模型使用 SwiftData 公开 `PersistentModel` 协议的显式实现，解决 CLT 未附带 SwiftData 宏插件的构建限制；没有替换为内存或 JSON 数据库。
- 原生断言运行结果：**2026-10-25 执行 `scripts/test-native.sh`，17/17 组通过，退出码 0**。包含 16 组共享断言和 1 组独立进程持久化检查。
- 最终原生测试复跑：主集成执行 17/17 通过，退出码 0；日志 `build/native-tests-final.log`。
- debug 与 release 的 `swift build` 均成功；记录见 `build/debug-build.log`、`build/release-build.log`。应用包 ad-hoc 签名及 `codesign` 验证通过，已安装到 `~/Applications/Dayline.app` 并真实启动。
- 桌面 File Provider 会给 `.app` 附加 FinderInfo，因此签名应用在 `~/Library/Caches/DaylineBuild/<项目标识>/Dayline.app` 组装；`build/Dayline.app` 是快捷链接，`build/Dayline-macOS.zip` 是便携包。安装应用是独立副本。
- `Dayline.xcodeproj` 与共享 scheme 已生成，`plutil` 语法检查通过；当前工具链没有可用的 `xcodebuild` / XCTest，未执行 Xcode 构建与测试。
- 真实 CUA 界面已检查默认 1160×780 与放大 1440×814 窗口、深色模式；拖动边缘未实际改变尺寸，**尚未验证最小尺寸**。

## 规则验证矩阵

| 检查 | 覆盖方式 | 结果 |
| --- | --- | --- |
| 计划日期或截止日期为今天；同时命中只计一次 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 昨日截止逾期；今日零点不逾期；完成后解除逾期 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 过去计划作为待安排；刷新不自动改期 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 洛杉矶 23 小时 / 25 小时 DST 日、跨时区 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 只有截止日期仍属于收件箱 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 空白标题拒绝；标题去除首尾空白 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 删除父目标保留子目标与任务；拒绝短期父目标和长期子目标 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 每日/每周后继生成、撤销重做不重复 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 跳过已错过周期且保持每周相位 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 备份替换恢复、稳定 ID 与内容保存 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 非 JSON、缺失版本、未来版本、重复 ID、悬空关联拒绝且原数据保留 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 备份恢复后完成撤销重做仍不复制后继 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 目标进度越界、循环层级备份拒绝且保留原数据 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 非法导入保留未保存编辑；非法新建不留下空壳记录 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 磁盘模型的三类 Observation 通知、验证回滚及回滚后再次观察 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 临时磁盘库重新打开保留任务/目标/关联 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |
| 独立进程写入后退出，再启动另一个进程读取 | 原生测试子进程 | 通过，写入和读取是两个独立进程 |
| 初始无演示数据；主动加载幂等 | 共享断言 / XCTest | 原生断言通过；XCTest 未执行 |

## 功能矩阵

「已实现」表示存在相应实现；每项验证仅限表中明确列出的操作。

| 功能 | 实现范围 | 验证状态 |
| --- | --- | --- |
| 原生应用窗口 | SwiftUI、AppKit、签名应用包 | release 构建、安装、启动和两种实际窗口尺寸通过 |
| 今天 | 按领域分组、日期 OR 去重、已完成折叠、待安排 | 日期规则通过；真实界面内联创建、完成与撤销通过 |
| 收件箱 | 未分类无计划且无目标；允许只有截止日期 | 原生规则断言通过 |
| 即将到来 | 未来一周日期导航 | 真实界面显示安排在明天的任务 |
| 三个领域 | Learning / Research / Health | 真实界面可见；目标关联自动设置 Research 已验证 |
| 目标 | 长短期、父子关联、状态、成果进度与行动进度 | 创建 Learning 长期目标及短期子目标通过；规则测试通过 |
| 任务编辑 | 标题、笔记、日期、领域、目标、优先级、重复 | 真实界面编辑标题、笔记、高优先级、明日计划、目标关联通过；重复规则原生测试通过 |
| 快捷操作 | `⌘N`、搜索、完成、撤销完成、拖动排序 | 搜索、完成与撤销已操作；拖动排序尚未人工验收 |
| 数据保存 | 本机 SwiftData、错误提示 | 临时库与独立进程测试通过；真实应用 `⌘Q` 后以同一 QA 数据库重开，任务和两个新目标保留 |
| 备份 | JSON 导出、确认替换恢复、严格校验 | 规则测试通过；实际导出 schemaVersion=1、3 个领域/4 个目标/7 个任务的 JSON；异步原生 sheet 导出、选择备份、确认替换及完整恢复通过，恢复后主窗口正常响应 |
| 浅色 / 深色 | 跟随系统或指定外观 | `⌘,` 打开设置并切换深色，实际窗口视觉检查通过 |

## 已执行的真实界面验收

- [x] release 应用构建、签名验证、安装到 `~/Applications/Dayline.app` 并启动。
- [x] 在独立 QA 数据库使用示例，今天与目标层级可见。
- [x] 今天内联输入并保存任务，完成后撤销，任务恢复。
- [x] 编辑验收任务的标题、笔记、高优先级与明日计划，选择目标后自动匹配 Research。
- [x] 即将到来页面显示明天安排的验收任务。
- [x] 创建 Learning 长期目标及其短期子目标。
- [x] `⌘Q` 退出，再用同一 QA 数据库、不带 `--demo` 重启；搜索「验收」仍找到新任务和两个新目标。
- [x] `⌘,` 打开设置并切换深色，检查默认 1160×780 与放大 1440×814 窗口。
- [x] 从保存面板实际导出 JSON，读取确认 schemaVersion=1，领域/目标/任务数量为 3/4/7，文件为 `build/qa-data/Dayline-2026-10-25.json`。
- [x] 最终异步原生 sheet 再次导出 `build/qa-data/Dayline-final-qa.json`，随后选择该备份并确认完整替换恢复；两次操作结束均显示成功提示，主窗口立即恢复正常响应。
- [x] 退出 QA 实例后正常打开已安装应用，正式首次启动仅有三个默认领域和空白 Today，无演示任务。
- [x] 正式空白库按 `⌘N` 打开任务编辑器，按 `Esc` 取消后仍为空状态。

## 尚未完成的人工边界验收

- [ ] 只输入标题的编辑器保存路径完整键盘验收（Today 内联标题回车保存已验证）。
- [ ] 在真实界面分别设置计划今天、截止今天、两者今天，确认可视列表不重复（底层规则已通过）。
- [ ] 昨日计划主动改期；重复任务完整图形撤销/重做流程（底层规则已通过）。
- [ ] 搜索笔记、清空搜索后返回原页、拖动排序及重启后的顺序。
- [ ] 导出/恢复面板取消、恢复确认取消及错误文件图形提示（成功导出、完整替换恢复与底层非法备份拒绝已验证）。
- [ ] 最小窗口尺寸、VoiceOver、完整键盘焦点、高对比度、减少动态效果。
- [ ] macOS 14 与 Intel Mac 真实运行。

导出首次使用同步面板时，文件已成功保存，但面板关闭后 CUA 的辅助功能读取超时；进程采样显示主线程处于空闲，并非已证实的应用死锁。主集成已把面板改为异步 sheet，并完成最终导出与恢复操作复验；成功提示出现，主窗口正常响应。取消路径与错误文件图形提示仍单列为未验收边界。

## 仍未覆盖

磁盘满、权限突变、进程在写入中崩溃、损坏的 SQLite/WAL 文件、超大数据集性能、未来版本迁移、多个进程同时修改、长时间跨午夜驻留刷新、系统时区运行时切换。恢复前验证不等于对所有系统 I/O 故障都完成了故障注入验证。

## 原生断言实际输出

```text
PASS Today scheduled OR due, once
PASS Overdue and explicit carryover
PASS DST and calendar boundaries
PASS Inbox retains due-only tasks
PASS Blank titles rejected and trimmed
PASS Goal deletion preserves descendants and tasks
PASS Recurrence undo/redo deduplication
PASS Recurrence skips missed intervals
PASS Backup field and identity round trip
PASS Invalid backups leave data intact
PASS Invalid goal progress and cycles are atomic
PASS Recurrence dedup survives backup restore
PASS Invalid import preserves pending edits and atomic creation
PASS Observed disk models and validation rollback
PASS Temporary disk store reopen
PASS Demo is explicit and idempotent
PASS Separate-process disk persistence
17/17 native checks passed
```

## 源码审查反馈

已向界面负责人报告并由其修正：目标编辑器连续两次保存可能让第二次成功掩盖第一次验证失败；新建记录先保存基础字段再保存其余字段可能留下部分记录。最终编辑器对新建草稿使用一次完整创建，现有目标只提交一次状态保存，失败在编辑器内显示。原生测试覆盖非法新建无残留及回滚后数据仍可编辑；真实界面已完成任务编辑与新建目标；故意触发验证失败的图形边界流程尚未逐项验收。

## 最终截图

- `Screenshots/02-today-light-final.png`：最终浅色 Today，隔离 QA 数据。
- `Screenshots/05-today-dark-final.png`：最终深色 Today，隔离 QA 数据。
- `Screenshots/06-first-launch-empty.png`：正式安装版空白首次启动。
- `Screenshots/01-today-before-polish.png`：优化前对照；本轮调整了强调色、待安排区域、任务行悬停布局及完成动画。

以上均来自真实运行的原生窗口。
