// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HCPilot",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "HCPilot", targets: ["HCPilotApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "HCPilotApp",
            dependencies: ["Alamofire", "Kingfisher"],
            path: "ios/HCPilotApp"
        )
    ]
)
