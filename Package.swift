// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dayline",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Dayline", targets: ["Dayline"])],
    targets: [
        .executableTarget(name: "Dayline"),
        .testTarget(name: "DaylineTests", dependencies: ["Dayline"])
    ],
    swiftLanguageVersions: [.v5]
)
