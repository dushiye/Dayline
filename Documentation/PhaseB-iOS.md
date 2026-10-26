# Phase B：iPhone 本地应用

日期：2026-10-26。分支 `feat/ios-mvp`。没有启用 CloudKit，没有打开正式 Mac 库，没有替换已安装的 Dayline v1.1.1。

## 分层

- `DaylineCore`：日期、重复身份、计划分析、品牌色。不导入 SwiftData 或 CloudKit。
- `DaylineData`：五个 SwiftData 模型和 `DaylineStore`。界面只通过这里读写。`cloudKitDatabase` 仍是 `.none`。
- 应用层：Mac 界面在 `Sources/Dayline`，iPhone 界面在 `Sources/DaylineIOS`。两边都不调用 CloudKit。

以后的同步应加在 `DaylineStore` 外侧的协调层，用业务 UUID 做记录身份。不要把 `PersistentIdentifier` 或 `CKRecord.ID` 写进界面和计划规则。换同步后端时，不需要重写五个页面。

## 模型

五个模型已放进 `DaylineData`。Mac 的 47 项 XCTest，包括 v1 夹具的打开、修改和重新打开，在搬迁后通过。实验使用仓库夹具和临时库，没有使用个人数据库。

模型仍带唯一约束，正式接 CloudKit 之前还要单独做 schema 升级。

## iPhone

Target 是 `DaylineIOS`，bundle id `app.dayline.ios`，iOS 17，版本 0.1.0（build 1）。数据在 App 自己的 Application Support 里。启动时如果路径正好是 Mac 的正式库，会拒绝打开。

iOS 27.1 运行时只带 iPhone Duo。普通直板机用另外安装的 iOS 27.0 模拟器（build 24A434，约 8 GB，Xcode 27.1 可直接使用）。实测设备：

- iPhone 17，iOS 27.0，浅色和深色
- iPhone SE（第三代），iOS 27.0
- iPhone 17 Pro Max，iOS 27.0

截图文件名以 `simulator-` 开头，并写明机型和 `ios27.0`。底部导航是应用自己的标签栏，避免 Duo 上系统 `TabView` 变成侧边浮条。日期选择在小屏上用全屏打开，整月都能看见。
