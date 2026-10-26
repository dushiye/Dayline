<p align="center">
  <img src="Documentation/Brand/dayline-icon.png" width="96" alt="Dayline 图标">
</p>

<h1 align="center">Dayline</h1>

<p align="center">
  一款本地优先的 macOS 个人效率应用。<br>
  安排今天真正要做的事，并把长期目标留在视线里。
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="docs/INSTALL_WITH_AI.md">交给 AI 安装</a> ·
  <a href="CONTRIBUTING.md">参与贡献</a>
</p>

Dayline 用 SwiftUI 和 SwiftData 写成，用来管理个人任务、目标和灵感。数据放在你自己的 Mac 上，没有账号，也没有网络同步。

Mac 版是目前适合每天使用的版本。仓库里还有一个实验性的 iPhone 应用。两者的数据各自独立，不能同步。CloudKit 尚未实现。

界面语言是中文。

## 功能

- **今天。** 计划日期或截止日期是今天的任务，按领域分组。更早未完成的计划留在「待重新安排」，应用不会悄悄把它们挪到今天。
- **即将到来与收件箱。** 未来一周，以及没有领域、计划日期和关联目标的任务。
- **目标。** 长期与短期目标、可选的父目标、日期，以及由你自己填写的成果进度。任务完成不会改写这个进度。
- **灵感。** 可以置顶、归档、关联领域或目标，也可以转成任务。
- **重复任务。** 每天或每周。完成当前一条时生成下一次，错过的周期会跳过，不会一次补出很多条。
- **导出。** 按日期范围或选中的灵感导出 PDF、PNG 或 Markdown。已有文件不会被覆盖。
- **历史。** 只读地查看计划与完成情况。容量建议只在积累了足够的计划日之后出现，并且不会自动改任务。

示例内容是可选的。新建资料库只有 Learning、Research、Health 三个领域和空白工作区。

<p align="center">
  <img src="Documentation/Screenshots/02-today-light-final.png" width="720" alt="今天，使用内置示例任务">
</p>

<p align="center">
  <img src="Documentation/Screenshots/03-goals-dark.png" width="720" alt="深色模式下的目标，使用示例目标">
</p>

<p align="center">
  <img src="Documentation/Screenshots/v11-ideas-light.png" width="720" alt="灵感，使用示例笔记">
</p>

<p align="center">
  <img src="Documentation/Screenshots/date-picker-task-light.png" width="720" alt="统一的日历日期选择">
</p>

## 系统要求

- macOS 14 或更新版本
- Apple Command Line Tools，或完整 Xcode
- 在 Apple 芯片或 Intel Mac 上各自构建

项目没有 Developer ID 签名，也没有公证。你在自己的 Mac 上构建的应用使用本机临时签名。不要从别人那里下载这种未公证的二进制，也不要关闭 Gatekeeper 来打开它。请从源码安装。

## 安装

### 在你的 Mac 上

```bash
git clone https://github.com/dushiye/Dayline.git
cd Dayline
scripts/check-environment.sh
scripts/build-macos.sh
scripts/install-macos.sh "$HOME/Applications/Dayline.app"
open "$HOME/Applications/Dayline.app"
```

`scripts/check-environment.sh` 检查 macOS 版本、Swift 和开发者目录。`scripts/build-macos.sh` 只构建，不安装。应用包放在 `~/Library/Caches/DaylineBuild/`，避免桌面文件同步破坏签名。仓库里的 `build/Dayline.app` 只是指向该缓存的快捷方式。

`scripts/install-macos.sh` 把应用复制到你指定的路径。它不会读取或写入 `~/Library/Application Support/Dayline`。

- 尚不存在的路径会被创建，包括第一次安装到 `~/Applications/Dayline.app`。
- 替换已经存在的 `~/Applications/Dayline.app` 必须设置 `DAYLINE_REPLACE_INSTALLED=yes`。旧应用会被改名保留。
- 替换其他已存在路径必须设置 `DAYLINE_REPLACE_DESTINATION=yes`。
- 脚本拒绝安装到个人数据目录。

不需要 `sudo`。脚本可以重复运行：再次构建会更新缓存里的应用包；再次安装在未设置确认变量时会停下来。

也可以在 Finder 中双击 `安装 Dayline.command`。如果已经安装过，终端会先询问是否把旧应用移到一旁。

### 用 Xcode 打开

```bash
open Dayline.xcodeproj
```

请打开 `.xcodeproj`，不要打开仓库文件夹。根目录的 `Package.swift` 会让 Xcode 把文件夹当成 Swift Package，从而看不到 Mac 和 iOS 的 scheme。

选择 **Dayline** scheme 和 **My Mac**。Mac 应用没有第三方依赖包。

### 更新

```bash
git pull
DAYLINE_REPLACE_INSTALLED=yes scripts/install-macos.sh "$HOME/Applications/Dayline.app"
```

更新应用不会替换数据库。做有风险的实验之前，用侧边栏菜单里的 **导出备份…**，把 JSON 另外保存一份。备份是可读的明文。

### 交给 AI 安装

把 [docs/INSTALL_WITH_AI.md](docs/INSTALL_WITH_AI.md) 里的提示词复制给 Cursor、Codex 或其他编程代理。提示词要求代理从源码构建，禁止接触已有的个人数据库，并在替换已安装应用前征求同意。

## 使用

- **新建任务：** `⌘N` 或右上角 **+**。只写标题也可以。
- **日期：** 计划日期是准备做的那天，截止日期是最晚完成的那天。两者使用同一个日历弹层。清除日期会关闭对应开关。
- **搜索：** 任务、目标和灵感正文。
- **灵感：** 侧边栏 **灵感**。转成任务后，原来的灵感仍会保留。
- **导出：** `⇧⌘E`。
- **外观：** 跟随系统，或指定浅色、深色。
- **示例内容：** 侧边栏菜单中的 **添加示例内容**。之后可以删除。

## 数据与隐私

数据库位于：

```text
~/Library/Application Support/Dayline/Dayline.store
```

同一目录还有 SQLite 的 WAL、SHM、升级时生成的快照，以及自动 JSON 备份。复制这个文件夹之前请先退出 Dayline。应用运行时不要删除或替换数据库、WAL 或 SHM。

这个仓库没有账号、没有统计上报，也没有云同步。备份 JSON 以明文保存你的任务，请把它当作私人文件。

## Mac 与 iPhone

| | Mac | iPhone |
| --- | --- | --- |
| 状态 | 可每天使用，版本 1.1.1 | 实验性，版本 0.1.0 |
| 安装 | 在你的 Mac 上从源码构建 | 需要 Xcode，以及 iOS 17+ 模拟器或你自己的设备签名 |
| 数据 | 本机 SwiftData | 另一份本机数据库 |
| 同步 | 无 | 无 |

iPhone 版包含今天、即将到来、收件箱、目标和灵感。它还不是完成品，也没有上架 App Store。安装到真机需要你在自己的 Xcode 里配置签名。本项目不会向你索取 Apple ID 密码。

<p align="center">
  <img src="Documentation/Screenshots/ios/simulator-iphone17-ios27.0-today-light.png" width="280" alt="实验性 iPhone 今天界面，使用示例任务">
</p>

## 路线

- 让 Mac 版继续适合每天使用。
- 让源码安装和更新更可预期。
- 改进实验性的 iPhone 版。
- 等本地数据模型稳定之后再设计同步。CloudKit 是以后的计划，不是现在的功能。
- 其他平台尚未排期。

## 参与贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。欢迎问题报告和拉取请求。请不要附上个人任务、数据库文件或签名凭据。

## 许可证

[MIT](LICENSE)。你可以自由使用、修改和再分发，包括商业用途，但需要保留版权声明和许可证文本。

## 作者

[dushiye](https://github.com/dushiye) · [github.com/dushiye/Dayline](https://github.com/dushiye/Dayline)
