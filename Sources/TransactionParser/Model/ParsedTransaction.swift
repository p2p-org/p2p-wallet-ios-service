// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation
import SolanaSwift

/// A parsed transaction struct. Useful for display to regular users
public struct ParsedTransaction: Hashable {
  /// Current status of transaction.
  public var status: Status

  /// A transaction signature
  public var signature: String?

  /// A detailed information about this transaction.
  ///
  /// For example the information about create account transaction is a fee amount and new created wallet,
  /// transfer - amount of transferred lamport, source, destination address, etc.
  public var info: AnyHashable?

  /// The current amount of value in fiat.
  public var amountInFiat: Double?

  /// The slot this transaction was processed in.
  public let slot: UInt64?

  /// Estimated production time, as Unix timestamp (seconds since the Unix epoch) of when the transaction was processed.
  /// Nil if not available.
  public var blockTime: Date?

  /// The fee amount this transaction was charged.
  public let fee: SolanaSDK.FeeAmount?

  /// The blockhash of this block
  public let blockhash: String?

  /// The bool value that indicates the fee was covered by the p2p validator.
  public var paidByP2POrg: Bool = false

  public init(
    status: Status,
    signature: String?,
    info _: AnyHashable?,
    amountInFiat: Double? = nil,
    slot: UInt64?,
    blockTime: Date?,
    fee: SolanaSDK.FeeAmount?,
    blockhash: String?,
    paidByP2POrg: Bool = false
  ) {
    self.status = status
    self.signature = signature
//    self.info = info
    self.amountInFiat = amountInFiat
    self.slot = slot
    self.blockTime = blockTime
    self.fee = fee
    self.blockhash = blockhash
    self.paidByP2POrg = paidByP2POrg
  }

  @available(*, deprecated, renamed: "info")
  public var value: AnyHashable? { info }

  public var amount: Double {
    if let info = info as? Info {
      return info.amount ?? 0
    }
    return 0
  }

  public var symbol: String {
    if let info = info as? Info {
      return info.symbol ?? ""
    }
    return ""
  }

  public var isProcessing: Bool {
    switch status {
    case .requesting, .processing:
      return true
    default:
      return false
    }
  }

  public var isFailure: Bool {
    switch status {
    case .error:
      return true
    default:
      return false
    }
  }
}

struct SwapTransaction: Hashable {
  public init(
    source: SolanaSDK.Wallet?,
    sourceAmount: Double?,
    destination: SolanaSDK.Wallet?,
    destinationAmount: Double?,
    myAccountSymbol: String?
  ) {
    self.source = source
    self.sourceAmount = sourceAmount
    self.destination = destination
    self.destinationAmount = destinationAmount
    self.myAccountSymbol = myAccountSymbol
  }

  public enum Direction {
    case spend, receive, transitiv
  }

  // source
  public let source: SolanaSDK.Wallet?
  public let sourceAmount: Double?

  // destination
  public let destination: SolanaSDK.Wallet?
  public let destinationAmount: Double?

  public var myAccountSymbol: String?

  static var empty: Self {
    SwapTransaction(
      source: nil,
      sourceAmount: nil,
      destination: nil,
      destinationAmount: nil,
      myAccountSymbol: nil
    )
  }

  public var direction: Direction {
    if myAccountSymbol == source?.token.symbol {
      return .spend
    }
    if myAccountSymbol == destination?.token.symbol {
      return .receive
    }
    return .transitiv
  }
}

extension ParsedTransaction {
  /// The enum of possible status of transaction in blockchain
  public enum Status: Equatable, Hashable {
    /// The transaction is in requesting process. The transaction can be being prepared or submitted.
    case requesting

    /// The transaction is processed by blockchain.
    case processing(percent: Double)

    /// The transaction has been done processed and is a part of blockchain
    case confirmed

    /// The transaction has been done processed but finished with error.
    case error(String?)

    /// Convert the status as error.
    public func getError() -> Error? {
      switch self {
      case let .error(err) where err != nil:
        return SolanaSDK.Error.other(err!)
      default:
        break
      }
      return nil
    }

    /// The raw string value
    public var rawValue: String {
      switch self {
      case .requesting:
        return "requesting"
      case .processing:
        return "processing"
      case .confirmed:
        return "confirmed"
      case .error:
        return "error"
      }
    }
  }
}
