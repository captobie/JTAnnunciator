// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JTAnnunciatorMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "JTAnnunciatorMac", targets: ["JTAnnunciatorMac"])
    ],
    dependencies: [
        .package(path: "../../..")
    ],
    targets: [
        .executableTarget(
            name: "JTAnnunciatorMac",
            dependencies: [
                .product(name: "JTAnnunciatorCore", package: "JTAnnunciator")
            ]
        )
    ]
)
