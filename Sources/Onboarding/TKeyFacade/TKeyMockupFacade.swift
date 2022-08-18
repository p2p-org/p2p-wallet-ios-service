// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation
import JSBridge
import WebKit

public class TKeyMockupFacade: TKeyFacade {
    public init() {}

    public func initialize() async throws {}

    public func signUp(tokenID _: TokenID) async throws -> SignUpResult {
        .init(
            privateSOL: "somePrivateKey",
            reconstructedETH: "someEthPublicKey",
            deviceShare: "someDeviceShare",
            customShare: "someCustomShare",
            metaData: "someMetadata"
        )
    }

    public func signIn(tokenID _: TokenID, deviceShare _: String) async throws -> SignInResult {
        .init(privateSOL: "somePrivateKey", reconstructedETH: "someEthPublicKey")
    }

    public func signIn(tokenID: TokenID, customShare: String) async throws -> SignInResult {
        .init(privateSOL: "somePrivateKey", reconstructedETH: "someEthPublicKey")
    }

    public func signIn(deviceShare: String, customShare: String) async throws -> SignInResult {
        .init(privateSOL: "somePrivateKey", reconstructedETH: "someEthPublicKey")
    }
}
