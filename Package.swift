// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Reisen",
    platforms: [
        .macOS(.v26),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ReisenDomain", targets: ["ReisenDomain"]),
        .library(name: "ReisenData", targets: ["ReisenData"]),
        .library(name: "ReisenProviders", targets: ["ReisenProviders"]),
        .library(name: "ReisenAppCore", targets: ["ReisenAppCore"]),
        .library(name: "ReisenSharedUI", targets: ["ReisenSharedUI"]),
        .library(name: "ReisenCheck24", targets: ["ReisenCheck24"]),
        .library(name: "ReisenOpodo", targets: ["ReisenOpodo"]),
        .library(name: "ReisenBookingCom", targets: ["ReisenBookingCom"]),
        .library(name: "ReisenAirbnb", targets: ["ReisenAirbnb"]),
        .executable(name: "Reisen", targets: ["Reisen"]),
    ],
    targets: [
        .target(
            name: "ReisenDomain",
            path: "Sources/ReisenDomain",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenData",
            dependencies: ["ReisenDomain"],
            path: "Sources/ReisenData",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenProviders",
            dependencies: ["ReisenDomain"],
            path: "Sources/ReisenProviders",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenAppCore",
            dependencies: [
                "ReisenDomain",
                "ReisenData",
                "ReisenProviders",
                "ReisenCheck24",
                "ReisenOpodo",
                "ReisenBookingCom",
                "ReisenAirbnb",
            ],
            path: "Sources/ReisenAppCore",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenSharedUI",
            dependencies: [
                "ReisenDomain",
                "ReisenData",
                "ReisenAppCore",
            ],
            path: "Sources/ReisenSharedUI",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenCheck24",
            dependencies: ["ReisenDomain", "ReisenProviders"],
            path: "Sources/ReisenCheck24",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenOpodo",
            dependencies: ["ReisenDomain", "ReisenProviders"],
            path: "Sources/ReisenOpodo",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenBookingCom",
            dependencies: ["ReisenDomain", "ReisenProviders"],
            path: "Sources/ReisenBookingCom",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenAirbnb",
            dependencies: ["ReisenDomain", "ReisenProviders"],
            path: "Sources/ReisenAirbnb",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .executableTarget(
            name: "Reisen",
            dependencies: [
                "ReisenDomain",
                "ReisenData",
                "ReisenProviders",
                "ReisenCheck24",
                "ReisenOpodo",
                "ReisenBookingCom",
                "ReisenAirbnb",
            ],
            path: "Sources/Reisen",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenDomainTests",
            dependencies: ["ReisenDomain"],
            path: "Tests/ReisenDomainTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenDataTests",
            dependencies: ["ReisenData", "ReisenDomain"],
            path: "Tests/ReisenDataTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenCheck24Tests",
            dependencies: ["ReisenCheck24", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenCheck24Tests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenOpodoTests",
            dependencies: ["ReisenOpodo", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenOpodoTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenBookingComTests",
            dependencies: ["ReisenBookingCom", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenBookingComTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenAirbnbTests",
            dependencies: ["ReisenAirbnb", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenAirbnbTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenProvidersTests",
            dependencies: ["ReisenProviders"],
            path: "Tests/ReisenProvidersTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
