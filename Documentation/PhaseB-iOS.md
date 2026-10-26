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

这台机器的 iOS 27.1 模拟器运行时只提供 iPhone Duo，不能创建 SE 或 Pro Max。界面检查用的是它的 1398×2034 显示屏。系统 `TabView` 在这台模拟器上会把标签画成右侧浮条并挡住列表，所以 iPhone 版使用底部标签栏。
