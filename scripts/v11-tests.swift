import Foundation

@main
struct V11Tests {
    @MainActor static func main() {
        do {
            let arguments = CommandLine.arguments
            if arguments.count == 3 {
                let url = URL(fileURLWithPath: arguments[2])
                if arguments[1] == "--seed-disk" { try V11Checks.seedDisk(url); return }
                if arguments[1] == "--check-disk" { try V11Checks.inspectDisk(url); return }
                throw CheckFailure(description: "Unknown v1.1 test mode")
            }
            var failures = 0
            for (name, check) in V11Checks.all {
                do { try check(); print("PASS \(name)") }
                catch { failures += 1; print("FAIL \(name): \(error)") }
            }
            do { try processRestart(); print("PASS Final Idea keystroke survives separate-process exit/reopen") }
            catch { failures += 1; print("FAIL Separate-process Idea durability: \(error)") }
            print("\(V11Checks.all.count + 1 - failures)/\(V11Checks.all.count + 1) v1.1 integration checks passed")
            if failures > 0 { exit(1) }
        } catch {
            fputs("FAIL \(error)\n", stderr); exit(1)
        }
    }

    @MainActor private static func processRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-v11-Process-\(UUID().uuidString)")
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
