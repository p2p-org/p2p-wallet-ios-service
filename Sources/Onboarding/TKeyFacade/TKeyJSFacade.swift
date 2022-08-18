// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation
import JSBridge
import WebKit

public struct TKeyJSFacadeConfiguration {
    let metadataEndpoint: String
    let torusEndpoint: String
    let torusVerifierMapping: [String: String]

    public init(metadataEndpoint: String, torusEndpoint: String, torusVerifierMapping: [String: String]) {
        self.metadataEndpoint = metadataEndpoint
        self.torusEndpoint = torusEndpoint
        self.torusVerifierMapping = torusVerifierMapping
    }
}

public class TKeyJSFacade: TKeyFacade {
    enum Error: Swift.Error {
        case canNotFindJSScript
        case facadeIsNotReady
        case invalidReturnValue
    }

    private let kLibrary: String = "p2pWeb3Auth"

    private let context: JSBContext
    private var facadeClass: JSBValue?
    private let config: TKeyJSFacadeConfiguration

    public init(wkWebView: WKWebView? = nil, config: TKeyJSFacadeConfiguration) {
        self.config = config
        context = JSBContext(wkWebView: wkWebView)
    }

    private var ready: Bool = false

    public func initialize() async throws {
        guard ready == false else { return }
        defer { ready = true }

        let records = await WKWebsiteDataStore.default()
            .fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        for record in records {
            await WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record])
        }

        let scriptPath = getSDKPath()
        let request = URLRequest(url: URL(fileURLWithPath: scriptPath))
        try await context.load(request: request)
        facadeClass = try await context.this.valueForKey("\(kLibrary).IosFacade")
    }

    private func getSDKPath() -> String {
        #if SWIFT_PACKAGE
            guard let scriptPath = Bundle.module.path(forResource: "index", ofType: "html") else {
                fatalError(Error.canNotFindJSScript.localizedDescription)
            }
        #else
            guard let scriptPath = Bundle(for: TKeyJSFacade.self).path(forResource: "index", ofType: "html") else {
                fatalError(Error.canNotFindJSScript.localizedDescription)
            }
        #endif

        return scriptPath
    }

    private func getFacade(configuration: [String: Any]) async throws -> JSBValue {
        let library = try getLibrary()
        return try await library.invokeNew(
            withArguments: [
                [
                    "metadataEndpoint": config.metadataEndpoint,
                    "torusEndpoint": config.torusEndpoint,
                ].merging(configuration, uniquingKeysWith: { $1 }),
            ]
        )
    }

    public func signUp(tokenID: TokenID) async throws -> SignUpResult {
        do {
            print(config)
            let facade = try await getFacade(configuration: [
                "type": "signup",
                "useNewEth": true,
                "torusLoginType": tokenID.provider,
                "torusVerifier": config.torusVerifierMapping[tokenID.provider],
            ])
            let value = try await facade.invokeAsyncMethod("triggerSilentSignup", withArguments: [tokenID.value])

            guard
                let privateSOL = try await value.valueForKey("privateSOL").toString(),
                let reconstructedETH = try await value.valueForKey("ethPublic").toString(),
                let deviceShare = try await value.valueForKey("deviceShare").toJSON(),
                let customShare = try await value.valueForKey("customShare").toJSON(),
                let metadata = try await value.valueForKey("metadata").toJSON()
            else {
                throw Error.invalidReturnValue
            }

            return .init(
                privateSOL: privateSOL,
                reconstructedETH: reconstructedETH,
                deviceShare: deviceShare,
                customShare: customShare,
                metaData: metadata
            )
        } catch let JSBError.jsError(error) {
            let parsedError = parseFacadeJSError(error: error)
            throw parsedError ?? JSBError.jsError(error)
        } catch {
            throw error
        }
    }

    public func signIn(tokenID: TokenID, deviceShare: String) async throws -> SignInResult {
        let facade = try await getFacade(configuration: [:])
        let value = try await facade.invokeAsyncMethod(
            "triggerSignInNoCustom",
            withArguments: [tokenID.value, deviceShare]
        )
        guard
            let result = try await value.toDictionary(),
            let privateSOL = result["privateSOL"] as? String,
            let reconstructedETH = result["reconstructedETH"] as? String
        else { throw Error.invalidReturnValue }

        return .init(
            privateSOL: privateSOL,
            reconstructedETH: reconstructedETH
        )
    }

    public func signIn(tokenID: TokenID, withCustomShare _: String) async throws -> SignInResult {
        let facade = try await getFacade(configuration: [:])
        let value = try await facade.invokeAsyncMethod(
            "triggerSignInNoDevice",
            withArguments: [tokenID.value]
        )
        guard
            let result = try await value.toDictionary(),
            let privateSOL = result["privateSOL"] as? String,
            let reconstructedETH = result["reconstructedETH"] as? String
        else { throw Error.invalidReturnValue }

        return .init(
            privateSOL: privateSOL,
            reconstructedETH: reconstructedETH
        )
    }

    func getLibrary() throws -> JSBValue {
        guard let library = facadeClass else {
            throw Error.facadeIsNotReady
        }
        return library
    }

    internal func parseFacadeJSError(error: Any) -> TKeyFacadeError? {
        guard
            let errorStr = error as? String,
            let error = try? errorStr.data(using: .utf8)
        else { return nil }

        return try? JSONDecoder().decode(TKeyFacadeError.self, from: error)
    }
}

extension WKWebsiteDataStore {
    func fetchDataRecords(ofTypes dataTypes: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { continuation in
            fetchDataRecords(ofTypes: dataTypes) { records in
                continuation.resume(returning: records)
            }
        }
    }
}
