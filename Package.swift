// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphifySwiftEvolution",
    platforms: [
          .macOS(.v10_14),
       ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.23.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.0"),
        .package(name: "Theo", url: "https://github.com/Neo4j-Swift/Neo4j-Swift.git", .branch("master")),
        .package(url: "https://github.com/Neo4j-Swift/Bolt-swift.git", .branch("master"))
    ],
    
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "GraphifySwiftEvolution",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                  "Theo"])//,
        //.testTarget(
         //   name: "GraphifySwiftTests",
         //   dependencies: ["GraphifySwift"]),
    ]
)
