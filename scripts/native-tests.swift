import Foundation

@main
struct NativeTests {
    @MainActor static func main() {
        do {
            let arguments = CommandLine.arguments
            if arguments.count == 3 {
                let url = URL(fileURLWithPath: arguments[2])
                if arguments[1] == "--seed-disk" { try RuleChecks.seedPersistentStore(url); return }
                if arguments[1] == "--check-disk" { try RuleChecks.inspectPersistentStore(url); return }
                throw CheckFailure(description: "Unknown native test mode")
            }
            var failures = 0
            for (name, check) in RuleChecks.all {
                do { try check(); print("PASS \(name)") }
                catch { failures += 1; print("FAIL \(name): \(error)") }
            }
            do { try processRestart(); print("PASS Separate-process disk persistence") }
            catch { failures += 1; print("FAIL Separate-process disk persistence: \(error)") }
            print("\(RuleChecks.all.count + 1 - failures)/\(RuleChecks.all.count + 1) native checks passed")
            if failures > 0 { exit(1) }
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor static func processRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-Process-QA-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("restart.store")
        for mode in ["--seed-disk", "--check-disk"] {
            let child = Process()
            child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            child.arguments = [mode, url.path]
            try child.run(); child.waitUntilExit()
            try RuleChecks.require(child.terminationStatus == 0, "Child process \(mode) exited \(child.terminationStatus)")
        }
    }
}
