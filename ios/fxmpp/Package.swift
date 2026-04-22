// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fxmpp",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "fxmpp", targets: ["fxmpp"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/robbiehanson/XMPPFramework", from: "4.1.0"),
    ],
    targets: [
        .target(
            name: "fxmpp",
            dependencies: [
                .product(name: "XMPPFramework", package: "XMPPFramework"),
            ],
            resources: [
                // TODO: If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        )
    ]
)
