// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MeihuaCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MeihuaCore", targets: ["MeihuaCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(name: "MeihuaCore", dependencies: ["ZIPFoundation"]),
        .testTarget(name: "MeihuaCoreTests", dependencies: ["MeihuaCore"])
    ]
)