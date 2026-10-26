// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DaylineData",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "DaylineData", targets: ["DaylineData"])
    ],
    dependencies: [
        .package(path: "../DaylineCore")
    ],
    targets: [
        .target(
            name: "DaylineData",
            dependencies: ["DaylineCore"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
