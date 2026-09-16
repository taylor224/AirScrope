// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WiFiAnalyzer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WiFiAnalyzer", targets: ["WiFiAnalyzer"])],
    targets: [
        .target(name: "WiFiCore", resources: [.process("Resources")]),
        .executableTarget(name: "WiFiAnalyzer", dependencies: ["WiFiCore"],
                          linkerSettings: [.linkedFramework("CoreWLAN"), .linkedFramework("CoreLocation")]),
        .testTarget(name: "WiFiCoreTests", dependencies: ["WiFiCore"])
    ]
)
