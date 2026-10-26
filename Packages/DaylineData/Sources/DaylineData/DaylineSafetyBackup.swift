import Foundation
import SQLite3

public enum DaylineSafetyBackup {
    /// SQLite's online backup includes committed WAL content, even if another reader is open.
    /// Never delete/recreate the source store if migration or backup fails.
    public static func beforeUpgrade(at source: URL) throws {
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let destination = source.deletingLastPathComponent()
            .appendingPathComponent(source.lastPathComponent + ".before-v1.1.sqlite")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let temporary = destination.appendingPathExtension(UUID().uuidString + ".partial")
        var reader: OpaquePointer?
        var writer: OpaquePointer?
        defer {
            if let reader { sqlite3_close(reader) }
            if let writer { sqlite3_close(writer) }
            try? FileManager.default.removeItem(at: temporary)
        }
        // A valid cold WAL store can have no sidecars. SQLite needs write permission to
        // initialize its transient WAL/SHM files; no CREATE flag or write SQL is used here.
        guard sqlite3_open_v2(source.path, &reader, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              sqlite3_open_v2(temporary.path, &writer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_EXCLUSIVE, nil) == SQLITE_OK else {
            throw DaylineDataError.invalid("升级前数据库备份无法创建；原数据库保持不变。")
        }
        sqlite3_busy_timeout(reader, 2000)
        sqlite3_busy_timeout(writer, 2000)
        guard let backup = sqlite3_backup_init(writer, "main", reader, "main") else {
            throw DaylineDataError.invalid("升级前数据库备份无法创建；原数据库保持不变。")
        }
        let result = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE && finish == SQLITE_OK else {
            throw DaylineDataError.invalid("升级前数据库备份未完成（SQLite \(result)/\(finish)），请退出其他 Dayline 实例后重试。")
        }
        // Finalize a single-file recovery snapshot, independent of transient WAL/SHM files.
        guard sqlite3_exec(writer, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {
            throw DaylineDataError.invalid("升级前数据库备份无法完成独立快照；原数据库记录保持不变。")
        }
        sqlite3_close(writer); writer = nil
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}
