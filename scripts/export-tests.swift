import Foundation

@main struct ExportTests {
    static func main() async {
        do {
            let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/export-samples"
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try ExportChecks.run(directory: directory)
            try await ExportChecks.cancellation(directory: directory)
            print("Samples: \(directory.path)")
        } catch {
            fputs("FAIL export: \(error)\n", stderr)
            exit(1)
        }
    }
}
