// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation
import SolanaPricesAPIs
import SolanaSwift

public struct UserWalletEnvironments: Equatable {
    let wallets: [Wallet]
    let exchangeRate: [String: CurrentPrice]

    public init(wallets: [Wallet], exchangeRate: [String: CurrentPrice]) {
        self.wallets = wallets
        self.exchangeRate = exchangeRate
    }

    public static func == (lhs: UserWalletEnvironments, rhs: UserWalletEnvironments) -> Bool {
        if lhs.wallets != rhs.wallets { return false }
        if lhs.exchangeRate != rhs.exchangeRate { return false }
        return true
    }
}
