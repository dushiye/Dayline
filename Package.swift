// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dayline",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Packages/DaylineCore"),
        .package(path: "Packages/DaylineData")
    ],
    products: [.executable(name: "Dayline", targets: ["Dayline"])],
    targets: [
        .executableTarget(name: "Dayline", dependencies: ["DaylineCore", "DaylineData"]),
        .testTarget(name: "DaylineTests", dependencies: ["Dayline", "DaylineCore", "DaylineData"])
    ],
    swiftLanguageVersions: [.v5]
)
