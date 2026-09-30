// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SavantKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "SavantKit", targets: ["SavantKit"])],
    targets: [
        .target(name: "SavantKit"),
        .testTarget(name: "SavantKitTests", dependencies: ["SavantKit"]),
    ]
)
