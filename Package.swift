// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Z33",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(name: "Z33Interpreter", targets: ["Z33Interpreter"]),
        .library(
            name: "Z33",
            targets: ["Z33"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/adtrevor/ParserBuilder.git", .branch("asciiopti")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Z33",
            dependencies: ["ParserBuilder"]),
        .target(name: "Z33Interpreter",
                dependencies: ["Z33"],
                swiftSettings: [
                    .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
                ]),
        .testTarget(
            name: "Z33Tests",
            dependencies: ["Z33"]),
    ]
)
