// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorkoutShared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "WorkoutShared", targets: ["WorkoutShared"])
    ],
    targets: [
        .target(name: "WorkoutShared"),
        .testTarget(name: "WorkoutSharedTests", dependencies: ["WorkoutShared"])
    ]
)
