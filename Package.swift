// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Reisen",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "ReisenDomain", targets: ["ReisenDomain"]),
        .library(name: "ReisenData", targets: ["ReisenData"]),
        .library(name: "ReisenDiagnostics", targets: ["ReisenDiagnostics"]),
        .library(name: "ReisenProviders", targets: ["ReisenProviders"]),
        .library(name: "ReisenAppCore", targets: ["ReisenAppCore"]),
        .library(name: "ReisenProviderSync", targets: ["ReisenProviderSync"]),
        .library(name: "ReisenSharedUI", targets: ["ReisenSharedUI"]),
        .library(name: "ReisenPasteImport", targets: ["ReisenPasteImport"]),
        .library(name: "ReisenCheck24", targets: ["ReisenCheck24"]),
        .library(name: "ReisenOpodo", targets: ["ReisenOpodo"]),
        .library(name: "ReisenBookingCom", targets: ["ReisenBookingCom"]),
        .library(name: "ReisenAirbnb", targets: ["ReisenAirbnb"]),
        .library(name: "ReisenGetYourGuide", targets: ["ReisenGetYourGuide"]),
        .library(name: "ReisenTraveloka", targets: ["ReisenTraveloka"]),
        .library(name: "ReisenBilligerMietwagen", targets: ["ReisenBilligerMietwagen"]),
        .executable(name: "Voyenna", targets: ["Reisen"]),
        .executable(name: "SyncIOSQuerySchemes", targets: ["SyncIOSQuerySchemes"]),
    ],
    targets: [
        .target(
            name: "ReisenDomain",
            path: "Sources/ReisenDomain",
            resources: [
                .process("Resources"),
            ],
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
            ],
            linkerSettings: [
                .linkedFramework("Security"),
            ]
        ),
        .target(
            name: "ReisenDiagnostics",
            dependencies: ["ReisenDomain"],
            path: "Sources/ReisenDiagnostics",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenProviders",
            dependencies: ["ReisenDomain", "ReisenDiagnostics"],
            path: "Sources/ReisenProviders",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("WebKit"),
            ]
        ),
        .target(
            name: "ReisenCrashSignal",
            path: "Sources/ReisenCrashSignal"
        ),
        .target(
            name: "ReisenAppCore",
            dependencies: [
                "ReisenDomain",
                "ReisenData",
                "ReisenDiagnostics",
                "ReisenCrashSignal",
            ],
            path: "Sources/ReisenAppCore",
            exclude: [
                "GitHubIssues/GitHubIssueToken.generated.swift.stub",
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenProviderSync",
            dependencies: [
                "ReisenAppCore",
                "ReisenDomain",
                "ReisenData",
                "ReisenProviders",
                "ReisenSharedUI",
                "ReisenCheck24",
                "ReisenOpodo",
                "ReisenBookingCom",
                "ReisenAirbnb",
                "ReisenGetYourGuide",
                "ReisenTraveloka",
                "ReisenBilligerMietwagen",
            ],
            path: "Sources/ReisenProviderSync",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("WebKit"),
            ]
        ),
        .target(
            name: "ReisenSharedUI",
            dependencies: [
                "ReisenDomain",
                "ReisenData",
                "ReisenAppCore",
                "ReisenDiagnostics",
            ],
            path: "Sources/ReisenSharedUI",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenPasteImport",
            dependencies: ["ReisenDomain", "ReisenAppCore"],
            path: "Sources/ReisenPasteImport",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("PDFKit"),
                .linkedFramework("Security", .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "ReisenCheck24",
            dependencies: ["ReisenDomain", "ReisenProviders", "ReisenDiagnostics"],
            path: "Sources/ReisenCheck24",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenOpodo",
            dependencies: ["ReisenDomain", "ReisenProviders", "ReisenDiagnostics"],
            path: "Sources/ReisenOpodo",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenBookingCom",
            dependencies: ["ReisenDomain", "ReisenProviders", "ReisenDiagnostics"],
            path: "Sources/ReisenBookingCom",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenAirbnb",
            dependencies: ["ReisenDomain", "ReisenProviders", "ReisenDiagnostics"],
            path: "Sources/ReisenAirbnb",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenGetYourGuide",
            dependencies: ["ReisenDomain", "ReisenProviders", "ReisenDiagnostics"],
            path: "Sources/ReisenGetYourGuide",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenTraveloka",
            dependencies: ["ReisenDomain", "ReisenProviders", "ReisenDiagnostics"],
            path: "Sources/ReisenTraveloka",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "ReisenBilligerMietwagen",
            dependencies: ["ReisenDomain", "ReisenProviders"],
            path: "Sources/ReisenBilligerMietwagen",
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
                "ReisenAppCore",
                "ReisenProviderSync",
                "ReisenSharedUI",
                "ReisenPasteImport",
            ],
            path: "Sources/Reisen",
            resources: [
                .process("Resources"),
                .copy("../../Resources/PrivacyInfo.xcprivacy"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .executableTarget(
            name: "SyncIOSQuerySchemes",
            dependencies: ["ReisenProviders"],
            path: "Sources/SyncIOSQuerySchemes",
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
            name: "ReisenSharedUITests",
            dependencies: ["ReisenSharedUI", "ReisenData", "ReisenDomain", "ReisenDiagnostics"],
            path: "Tests/ReisenSharedUITests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenPasteImportTests",
            dependencies: ["ReisenPasteImport", "ReisenDomain"],
            path: "Tests/ReisenPasteImportTests",
            resources: [
                .copy("Fixtures"),
            ],
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
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenBookingComTests",
            dependencies: ["ReisenBookingCom", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenBookingComTests",
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenAirbnbTests",
            dependencies: ["ReisenAirbnb", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenAirbnbTests",
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenGetYourGuideTests",
            dependencies: ["ReisenGetYourGuide", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenGetYourGuideTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenTravelokaTests",
            dependencies: ["ReisenTraveloka", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenTravelokaTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenBilligerMietwagenTests",
            dependencies: ["ReisenBilligerMietwagen", "ReisenDomain", "ReisenProviders"],
            path: "Tests/ReisenBilligerMietwagenTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenProvidersTests",
            dependencies: ["ReisenProviders", "ReisenDomain", "ReisenDiagnostics"],
            path: "Tests/ReisenProvidersTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenAppCoreTests",
            dependencies: ["ReisenAppCore", "ReisenData", "ReisenDomain", "ReisenCrashSignal", "ReisenDiagnostics"],
            path: "Tests/ReisenAppCoreTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReisenProviderSyncTests",
            dependencies: ["ReisenProviderSync", "ReisenDomain"],
            path: "Tests/ReisenProviderSyncTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
