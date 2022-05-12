// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import SolanaSwift
import XCTest
@testable import TransactionParser

class OrcaSwapStrategyTests: XCTestCase {
  let endpoint = APIEndPoint.defaultEndpoints.first!

  lazy var apiClient = JSONRPCAPIClient(endpoint: endpoint)
  lazy var tokensRepository = TokensRepository(endpoint: endpoint)
  lazy var strategy = OrcaSwapParseStrategy(apiClient: apiClient, tokensRepository: tokensRepository)

  func testParsingSuccessfulTransaction() async throws {
    let trx = Bundle.module.decode(TransactionInfo.self, from: "trx-swap-orca-ok.json")

    // Parse
    let parsedTransaction = try await strategy.parse(
      trx,
      config: .init(accountView: nil, symbolView: nil, feePayers: [])
    )

    // Tests
    guard let parsedTransaction = parsedTransaction as? SwapInfo else {
      XCTFail("Info should be SwapInfo")
      return
    }

    XCTAssertEqual(parsedTransaction.sourceAmount, 0.001)
    XCTAssertEqual(parsedTransaction.source?.pubkey, "BjUEdE292SLEq9mMeKtY3GXL6wirn7DqJPhrukCqAUua")
    XCTAssertEqual(parsedTransaction.source?.token.symbol, "SRM")

    XCTAssertEqual(parsedTransaction.destinationAmount, 0.00036488500000000001)
    XCTAssertEqual(parsedTransaction.destination?.pubkey, "BjUEdE292SLEq9mMeKtY3GXL6wirn7DqJPhrukCqAUua")
    XCTAssertEqual(parsedTransaction.destination?.token.symbol, "SOL")
  }

  func testParsingTransitiveTransaction() async throws {
    let trx = Bundle.module.decode(TransactionInfo.self, from: "trx-swap-orca-transitive-ok.json")

    // Parse
    let parsedTransaction = try await strategy.parse(
      trx,
      config: .init(accountView: nil, symbolView: nil, feePayers: [])
    )

    // Tests
    guard let parsedTransaction = parsedTransaction as? SwapInfo else {
      XCTFail("Info should be SwapInfo")
      return
    }

    print(parsedTransaction)
    
    XCTAssertEqual(parsedTransaction.sourceAmount, 0.000999999)
    XCTAssertEqual(parsedTransaction.source?.pubkey, "HVc47am8HPYgvkkCiFJzV6Q8qsJJKJUYT6o7ucd6ZYXY")
    XCTAssertEqual(parsedTransaction.source?.token.symbol, "SOL")

    XCTAssertEqual(parsedTransaction.destinationAmount, 0.088808)
    XCTAssertEqual(parsedTransaction.destination?.pubkey, "HVc47am8HPYgvkkCiFJzV6Q8qsJJKJUYT6o7ucd6ZYXY")
    XCTAssertEqual(parsedTransaction.destination?.token.symbol, "SLIM")
  }

  func testParsingFailedTransaction() async throws {
    let trx = Bundle.module.decode(TransactionInfo.self, from: "trx-swap-orca-error.json")

    // Parse
    let parsedTransaction = try await strategy.parse(
      trx,
      config: .init(accountView: nil, symbolView: nil, feePayers: [])
    )

    // Tests
    guard let parsedTransaction = parsedTransaction as? SwapInfo else {
      XCTFail("Info should be SwapInfo")
      return
    }

    XCTAssertEqual(parsedTransaction.sourceAmount, 100.0)
    XCTAssertEqual(parsedTransaction.source?.pubkey, "2xKofw1wK2CVMVUssGTv3G5pVrUALAR9r8J9zZnwtrUG")
    XCTAssertEqual(parsedTransaction.source?.token.symbol, "KIN")

    XCTAssertNil(parsedTransaction.destinationAmount)
    XCTAssertEqual(parsedTransaction.destination?.pubkey, "G8PrkEwmVx3kt3rXBin5o1bdDC1cvz7oBnXbHksNg7R4")
    XCTAssertEqual(parsedTransaction.destination?.token.symbol, "SOL")
  }
}
