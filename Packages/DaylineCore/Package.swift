// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DaylineCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "DaylineCore", targets: ["DaylineCore"])
    ],
    targets: [
        .target(name: "DaylineCore"),
        .testTarget(name: "DaylineCoreTests", dependencies: ["DaylineCore"])
    ]
)
