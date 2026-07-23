// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CashuKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "CashuKit",
            targets: ["CashuKit"]),
    ],
    dependencies: [
        .package(path: "../CoreCashu"),
//        .package(url: "https://github.com/SparrowTek/CoreCashu.git", branch: "main"),
        // bdk-swift removed: nothing in Sources/ imported BitcoinDevKit, and its binary
        // xcframework ships no tvOS/watchOS/visionOS slices — carrying it broke three of
        // the declared platforms and bloated every consuming app. Re-add when on-chain
        // support actually lands.
        // Vault removed: it cannot set kSecAttrAccessible, which the wallet's keychain
        // items require (ThisDeviceOnly). KeychainSecureStore now delegates to
        // CoreCashu's keychain store instead.
    ],
    targets: [
        .target(
            name: "CashuKit",
            dependencies: [
                .product(name: "CoreCashu", package: "CoreCashu"),
            ],
            // Swift 6 language mode (declared below) covers strict concurrency in both
            // debug and release. The earlier `unsafeFlags(..., .when(.debug))` was redundant
            // in debug and skipped enforcement in release.
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "CashuKitTests",
            dependencies: ["CashuKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
