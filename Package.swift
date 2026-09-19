// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JTAnnunciator",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "JTAnnunciatorCore", targets: ["JTAnnunciatorCore"])
    ],
    targets: [
        .target(name: "JTAnnunciatorCore"),
        .testTarget(name: "JTAnnunciatorCoreTests", dependencies: ["JTAnnunciatorCore"])
    ]
)
