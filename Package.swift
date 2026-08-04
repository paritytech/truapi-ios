// swift-tools-version: 5.10
//
// TrUAPIHost — iOS host package for the Rust TrUAPI core, consumed as an SPM
// git dependency. The Rust core lives in the paritytech/truapi repo; the
// uniffi-generated bindings and the container bundle are committed build
// outputs (regenerate with scripts/rebuild.sh against a truapi checkout); the
// xcframework is gitignored and distributed as a GitHub release asset
// (scripts/publish.sh).

import PackageDescription

// Flip to true to build against the locally generated
// Binaries/truapi_server.xcframework (run rebuild.sh first);
// false consumes the published release asset below (updated by publish.sh).
let useLocalBinary = false

let publishedBinaryURL = "https://github.com/paritytech/truapi-ios/releases/download/v0.1.0/truapi_server.xcframework.zip"
let publishedBinaryChecksum = "71b6f33f765ee4298dc1644f36a91bb461058fe9d7b39bd4d9a0cf183ea42cfb"

let binaryTarget: Target = useLocalBinary
    ? .binaryTarget(
        name: "truapi_serverFFI_binary",
        path: "Binaries/truapi_server.xcframework"
    )
    : .binaryTarget(
        name: "truapi_serverFFI_binary",
        url: publishedBinaryURL,
        checksum: publishedBinaryChecksum
    )

let package = Package(
    name: "TrUAPIHost",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TrUAPIHost", targets: ["TrUAPIHost"])
    ],
    targets: [
        .systemLibrary(
            name: "truapi_serverFFI",
            path: "Sources/truapi_serverFFI/include",
            pkgConfig: nil,
            providers: []
        ),
        binaryTarget,
        .target(
            name: "TrUAPIHost",
            dependencies: ["truapi_serverFFI", "truapi_serverFFI_binary"],
            path: "Sources/TrUAPIHost",
            resources: [.copy("Resources/truapi-container.js")]
        ),
        .testTarget(
            name: "TrUAPIHostTests",
            dependencies: ["TrUAPIHost"],
            path: "Tests"
        ),
    ]
)
