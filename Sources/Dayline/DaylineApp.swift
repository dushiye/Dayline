import SwiftUI
import SwiftData
import AppKit
import DaylineData

@main
struct DaylineApp: App {
    @NSApplicationDelegateAdaptor(DaylineAppDelegate.self) private var delegate
    @State private var store: DaylineStore?
    @State private var launchError: String?
    @AppStorage("appearance") private var appearance = "system"

    init() {
        do {
            let process = ProcessInfo.processInfo
            let args = process.arguments
            var storeURL: URL?
            if process.environment["DAYLINE_XCTEST_MODE"] == "1" {
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Dayline-XCTest-\(process.processIdentifier)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                storeURL = directory.appendingPathComponent("Dayline.store")
            } else if let index = args.firstIndex(of: "--qa-store"), args.indices.contains(index + 1) {
                storeURL = URL(fileURLWithPath: args[index + 1])
            }
            let container = try DaylineStore.makeContainer(url: storeURL)
            let backupDirectory = (storeURL?.deletingLastPathComponent() ??
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Dayline"))
                .appendingPathComponent("Automatic Backups", isDirectory: true)
            let value = try DaylineStore(container: container, automaticBackupDirectory: backupDirectory)
            if args.contains("--demo"), storeURL != nil { value.loadDemoData() }
            _store = State(initialValue: value)
        } catch {
            _launchError = State(initialValue: error.localizedDescription)
        }
    }

    private var colorScheme: ColorScheme? {
        let process = ProcessInfo.processInfo
        if process.arguments.contains("--qa-store"),
           let override = process.environment["DAYLINE_APPEARANCE"] {
            if override == "dark" { return .dark }
            if override == "light" { return .light }
        }
        return appearance == "dark" ? .dark : appearance == "light" ? .light : nil
    }

    var body: some Scene {
        Window("Dayline", id: "main") {
            Group {
                if let store {
                    DaylineRootView()
                        .environment(store)
                        .modelContainer(store.container)
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("暂时无法打开数据库").font(.title2.weight(.semibold))
                        Text(launchError ?? "未知错误").foregroundStyle(.secondary).textSelection(.enabled)
                        Text("原有数据已保留。请检查磁盘空间与文件权限，然后重新打开 Dayline。").font(.callout)
                        Button("退出 Dayline") { NSApp.terminate(nil) }
                    }.padding(48).frame(minWidth: 600, minHeight: 420)
                }
            }
            .preferredColorScheme(colorScheme)
            .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1160, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建任务") { NotificationCenter.default.post(name: .daylineNewTask, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
                Divider()
                Button("导出计划、灵感或回顾…") { NotificationCenter.default.post(name: .daylineExport, object: nil) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button("打开数据文件夹") {
                    if let url = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
                        NSWorkspace.shared.open(url.appendingPathComponent("Dayline"))
                    }
                }
            }
        }
        Settings {
            Form {
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                Text("数据保存在这台 Mac。每日启动或跨日时自动备份，回顾结束时另存安全快照，恢复前也会保留备份。可从「文件」导出 PDF、Markdown 或 PNG。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .frame(width: 420, height: 210)
            .preferredColorScheme(colorScheme)
        }
    }
}

extension Notification.Name {
    static let daylineNewTask = Notification.Name("dayline.newTask")
    static let daylineExport = Notification.Name("dayline.export")
    static let daylineWillTerminate = Notification.Name("dayline.willTerminate")
}

final class DaylineAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .daylineWillTerminate, object: nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil) }
        return true
    }
}
