// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftForum",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftForum",
            targets: ["SwiftForum"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/amraboelela/TwisterFoundation.git", .branch("master")),
    ],
    targets: [
        .target(name: "SwiftForum", dependencies: [
            .product(name: "TwisterFoundation", package: "TwisterFoundation"),
        ]),
        .testTarget(name: "SwiftForumTests", dependencies: ["SwiftForum"]),
    ]
)
