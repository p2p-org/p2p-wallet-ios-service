// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation
import SolanaSwift

public struct CreateAccountInfo: Hashable {
  /// The amount of fee in SOL.
  public let fee: Double?

  /// The created wallet.
  public let newWallet: SolanaSDK.Wallet?

  public init(fee: Double?, newWallet: SolanaSDK.Wallet?) {
    self.fee = fee
    self.newWallet = newWallet
  }

  public static var empty: Self {
    CreateAccountInfo(fee: nil, newWallet: nil)
  }
}

extension CreateAccountInfo: Info {
  public var amount: Double? { -(fee ?? 0) }
  public var symbol: String? { "SOL" }
}
