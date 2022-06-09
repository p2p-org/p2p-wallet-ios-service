// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SolanaSwiftMagic",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "TransactionParser",
      targets: ["TransactionParser"]
    ),
    .library(
      name: "NameService",
      targets: ["NameService"]
    ),
    // Analytics manager for wallet
    .library(
      name: "AnalyticsManager",
      targets: ["AnalyticsManager"]
    ),
    // Price service for wallet
    .library(
      name: "PricesService",
      targets: ["PricesService"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/p2p-org/solana-swift", from: "2.0.1"),
    .package(name: "Amplitude", url: "https://github.com/amplitude/Amplitude-iOS", from: "8.3.0")
  ],
  targets: [
    .target(
      name: "Common"
    ),
    .target(
      name: "TransactionParser",
      dependencies: [
        .product(name: "SolanaSwift", package: "solana-swift"),
      ]
    ),
    .testTarget(
      name: "TransactionParserTests",
      dependencies: ["TransactionParser"],
      resources: [.process("./Resource")]
    ),
    .target(
      name: "NameService",
      dependencies: ["Common"]
    ),
    // AnalyticsManager
    .target(
      name: "AnalyticsManager",
      dependencies: ["Amplitude"]
    ),
    .testTarget(
      name: "AnalyticsManagerTests",
      dependencies: ["AnalyticsManager"]
//      resources: [.process("./Resource")]
    ),
    // PricesService
    .target(
      name: "PricesService",
      dependencies: ["Common"]
    ),
    .testTarget(
      name: "PricesServiceTests",
      dependencies: ["PricesService"]
//      resources: [.process("./Resource")]
    ),
  ]
)

#if swift(>=5.6)
  // For generating docs purpose
  package.dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
#endif
