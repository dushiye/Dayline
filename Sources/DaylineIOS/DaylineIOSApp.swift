import SwiftUI
import DaylineData

@main
struct DaylineIOSApp: App {
    @State private var store: DaylineStore?
    @State private var launchError: String?

    init() {
        do {
            let url = try DaylineIOSLocation.storeURL()
            let container = try DaylineStore.makeContainer(url: url)
            let backups = url.deletingLastPathComponent().appendingPathComponent("Automatic Backups", isDirectory: true)
            let value = try DaylineStore(container: container, automaticBackupDirectory: backups)
            if ProcessInfo.processInfo.arguments.contains("--demo") { value.loadDemoData() }
            _store = State(initialValue: value)
        } catch {
            _launchError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let store {
                PhoneRootView(initialTab: PhoneTab.fromLaunch())
                    .environment(store)
            } else {
                ContentUnavailableView("暂时无法打开数据库", systemImage: "externaldrive.badge.exclamationmark", description: Text(launchError ?? "未知错误"))
                    .padding()
            }
        }
    }
}

enum DaylineIOSLocation {
    /// Simulator and device containers are not the Mac library path. A path that is exactly
    /// the installed Mac database is refused before SwiftData opens it.
    static func storeURL() throws -> URL {
        let process = ProcessInfo.processInfo
        if process.environment["DAYLINE_XCTEST_MODE"] == "1" || process.arguments.contains("--uitest") {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-iOS-\(process.processIdentifier)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("Dayline.store")
        }
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = base.appendingPathComponent("Dayline", isDirectory: true).appendingPathComponent("Dayline.store")
        let formal = URL(fileURLWithPath: "/Users/\(NSUserName())/Library/Application Support/Dayline/Dayline.store").standardizedFileURL
        if url.standardizedFileURL == formal {
            throw DaylineDataError.invalid("iPhone 版不能打开 Mac 的正式数据库。")
        }
        return url
    }
}
