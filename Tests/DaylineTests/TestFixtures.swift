import Foundation

private final class DaylineTestBundleToken: NSObject { }

enum DaylineTestFixtures {
    static func url(_ name: String) -> URL {
        let bundle = Bundle(for: DaylineTestBundleToken.self)
        if let bundled = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: nil) {
            return bundled
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent(name)
    }
}
