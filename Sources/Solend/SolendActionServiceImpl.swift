// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Combine
import FeeRelayerSwift
import Foundation
import P2PSwift
import SolanaSwift

public class SolendActionServiceImpl: SolendActionService {
    private let lendingMark: String
    private let userAccountStorage: SolanaAccountStorage
    private let rpcUrl: String

    private let solend: Solend
    private let solana: SolanaAPIClient

    private let feeRelayApi: FeeRelayerAPIClient
    private let feeRelay: FeeRelayer
    private let feeRelayContextManager: FeeRelayerContextManager

    private var owner: Account {
        get throws {
            guard let account = userAccountStorage.account else {
                throw SolanaError.unauthorized
            }
            return account
        }
    }

    public init(
        rpcUrl: String,
        lendingMark: String,
        userAccountStorage: SolanaAccountStorage,
        solend: Solend,
        solana: SolanaAPIClient,
        feeRelayApi: FeeRelayerAPIClient,
        feeRelay: FeeRelayer,
        feeRelayContextManager: FeeRelayerContextManager
    ) {
        self.rpcUrl = rpcUrl
        self.lendingMark = lendingMark
        self.userAccountStorage = userAccountStorage
        self.solend = solend
        self.solana = solana
        self.feeRelayApi = feeRelayApi
        self.feeRelay = feeRelay
        self.feeRelayContextManager = feeRelayContextManager
    }

    private let currentActionSubject: CurrentValueSubject<SolendAction?, Never> = .init(nil)
    public var currentAction: AnyPublisher<SolendAction?, Never> {
        currentActionSubject.eraseToAnyPublisher()
    }

    public func clearAction() throws {
        currentActionSubject.send(nil)
    }

    public func check() async throws {
        if let currentAction = getCurrentAction() {
            switch currentAction.status {
            case .processing:
                throw SolendActionError.actionIsAlreadyRunning
            default: break
            }
        }
    }

    public func depositFee(amount: UInt64, symbol: SolendSymbol) async throws -> SolanaSwift.FeeAmount {
        let feeRelayContext = try await feeRelayContextManager.getCurrentContext()
        let coveredByFeeRelay = feeRelayContext.usageStatus.currentUsage < feeRelayContext.usageStatus.maxUsage

        let depositFee = try await solend.getDepositFee(
            rpcUrl: rpcUrl,
            owner: owner.publicKey.base58EncodedString,
            feePayer: feeRelayContext.feePayerAddress.base58EncodedString,
            tokenAmount: amount,
            tokenSymbol: symbol
        )

        return .init(
            transaction: coveredByFeeRelay ? 0 : depositFee.fee,
            accountBalances: depositFee.rent
        )
    }

    public func withdrawFee(amount _: UInt64, symbol _: SolendSymbol) async throws -> SolanaSwift.FeeAmount {
        let feeRelayContext = try await feeRelayContextManager.getCurrentContext()
        let coveredByFeeRelay = feeRelayContext.usageStatus.currentUsage < feeRelayContext.usageStatus.maxUsage

        return .init(
            transaction: coveredByFeeRelay ? 0 : feeRelayContext.lamportsPerSignature * 2,
            accountBalances: 0
        )
    }

    public func deposit(
        amount: UInt64,
        symbol: String,
        feePayer: FeeRelayerSwift.TokenAccount?
    ) async throws {
        do {
            try await check()

            let feeRelayContext = try await feeRelayContextManager.getCurrentContext()
            let feePayerAddress: PublicKey = feeRelayContext.feePayerAddress

            let transactionsRaw: [SolanaSerializedTransaction] = try await solend.createDepositTransaction(
                solanaRpcUrl: rpcUrl,
                relayProgramId: RelayProgram.id(network: .mainnetBeta).base58EncodedString,
                amount: amount,
                symbol: symbol,
                ownerAddress: owner.publicKey.base58EncodedString,
                environment: .production,
                lendingMarketAddress: lendingMark,
                blockHash: try await solana.getRecentBlockhash(commitment: nil),
                freeTransactionsCount: UInt32(
                    feeRelayContext.usageStatus.maxUsage - feeRelayContext.usageStatus.currentUsage
                ),
                needToUseRelay: true,
                payInFeeToken: nil,
                feePayerAddress: feePayerAddress.base58EncodedString
            )

            let initialAction = SolendAction(
                type: .deposit,
                transactionID: nil,
                status: .processing,
                amount: amount,
                symbol: symbol
            )

            let depositFee = try await depositFee(amount: amount, symbol: symbol)
            try await relay(
                transactionsRaw: transactionsRaw,
                feeRelayContext: feeRelayContext,
                fee: depositFee,
                feePayer: feePayer,
                initialAction: initialAction
            )
        } catch {
            currentActionSubject.send(.init(
                type: .deposit,
                transactionID: nil,
                status: .failed(msg: error.localizedDescription),
                amount: amount,
                symbol: symbol
            ))
            throw error
        }
    }

    public func withdraw(
        amount: UInt64,
        symbol: SolendSymbol,
        feePayer: FeeRelayerSwift.TokenAccount?
    ) async throws {
        do {
            try await check()

            let feeRelayContext = try await feeRelayContextManager.getCurrentContext()
            let feePayerAddress: PublicKey = feeRelayContext.feePayerAddress

            let transactionsRaw: [SolanaSerializedTransaction] = try await solend.createWithdrawTransaction(
                solanaRpcUrl: rpcUrl,
                relayProgramId: RelayProgram.id(network: .mainnetBeta).base58EncodedString,
                amount: amount,
                symbol: symbol,
                ownerAddress: owner.publicKey.base58EncodedString,
                environment: .production,
                lendingMarketAddress: lendingMark,
                blockHash: try await solana.getRecentBlockhash(commitment: nil),
                freeTransactionsCount: UInt32(
                    feeRelayContext.usageStatus.maxUsage - feeRelayContext.usageStatus.currentUsage
                ),
                needToUseRelay: true,
                payInFeeToken: nil,
                feePayerAddress: feePayerAddress.base58EncodedString
            )

            let initialAction = SolendAction(
                type: .withdraw,
                transactionID: nil,
                status: .processing,
                amount: amount,
                symbol: symbol
            )

            let withdrawFee = try await withdrawFee(amount: amount, symbol: symbol)
            try await relay(
                transactionsRaw: transactionsRaw,
                feeRelayContext: feeRelayContext,
                fee: withdrawFee,
                feePayer: feePayer,
                initialAction: initialAction
            )
        } catch {
            currentActionSubject.send(.init(
                type: .withdraw,
                transactionID: nil,
                status: .failed(msg: error.localizedDescription),
                amount: amount,
                symbol: symbol
            ))
            throw error
        }
    }

    func submitTransaction(
        transactionsRaw: [SolanaSerializedTransaction],
        initialAction: SolendAction
    ) async throws {
        var ids: [String] = []

        // Sign transactions
        let transactions: [Transaction] = try transactionsRaw
            .map { (trx: String) -> Data in Data(Base58.decode(trx)) }
            .map { (trxData: Data) -> Transaction in
                var trx = try Transaction.from(data: trxData)
                try trx.sign(signers: [owner])
                return trx
            }

        for var transaction in transactions {
            let transactionID = try await solana.sendTransaction(
                transaction: try transaction.serialize().base64EncodedString(),
                configs: RequestConfiguration(encoding: "base64")!
            )
            ids.append(transactionID)
        }
        // Listen last transaction
        guard let primaryTrxId = ids.last else { throw SolanaError.unknown }
        Task.detached(priority: .utility) { [self] in
            try await listenTransactionStatus(
                transactionID: primaryTrxId,
                initialAction: initialAction
            )
        }
    }

    func relay(
        transactionsRaw: [SolanaSerializedTransaction],
        feeRelayContext: FeeRelayerContext,
        fee: FeeAmount,
        feePayer: FeeRelayerSwift.TokenAccount?,
        initialAction: SolendAction
    ) async throws {
        // Sign transactions
        let transactions: [Transaction] = try transactionsRaw
            .map { (trx: String) -> Data in Data(Base58.decode(trx)) }
            .map { (trxData: Data) -> Transaction in
                var trx = try Transaction.from(data: trxData)
                try trx.sign(signers: [owner])

                print("=== Transaction ===")
                print(try trx.serialize(requiredAllSignatures: false, verifySignatures: false).base64EncodedString())

                // Temporary fix for fee relay
                if
                    let lastInstruction = trx.instructions.last,
                    try lastInstruction.programId == PublicKey(string: "12YKFL4mnZz6CBEGePrf293mEzueQM3h8VLPUJsKpGs9")
                {
                    trx.instructions.removeLast()
                }

                print(try trx.serialize(requiredAllSignatures: false, verifySignatures: false).base64EncodedString())

                return trx
            }

        // Send transactions
        var ids: [String] = []
        // Allow only one transaction for using with relay. We can not calculate fee for others transactions
        guard transactions.count == 1 else { throw SolendActionError.expectedOneTransaction }

        // Setup fee payer
        let feePayer: FeeRelayerSwift.TokenAccount? = try feePayer ?? .init(
            address: try owner.publicKey,
            mint: PublicKey.wrappedSOLMint
        )

        // Prepare transaction
        let preparedTransactions = try transactions.map { (trx: Transaction) -> PreparedTransaction in
            PreparedTransaction(
                transaction: trx,
                signers: [try owner],
                expectedFee: fee
            )
        }

        // Relay transaction
        let transactionsIDs = try await feeRelay.topUpAndRelayTransaction(
            feeRelayContext,
            preparedTransactions,
            fee: feePayer,
            config: .init(
                operationType: .other,
                autoPayback: true
            )
        )
        ids.append(contentsOf: transactionsIDs)

        // Listen last transaction
        guard let primaryTrxId = ids.last else { throw SolanaError.unknown }
        Task.detached(priority: .utility) { [self] in
            try await listenTransactionStatus(
                transactionID: primaryTrxId,
                initialAction: initialAction
            )
        }
    }

    func directRelay(
        transactionsRaw: [SolanaSerializedTransaction],
        fee: FeeAmount,
        initialAction: SolendAction
    ) async throws {
        // Sign transactions
        let transactions: [Transaction] = try transactionsRaw
            .map { (trx: String) -> Data in Data(Base58.decode(trx)) }
            .map { (trxData: Data) -> Transaction in
                var trx = try Transaction.from(data: trxData)
                try trx.sign(signers: [owner])
                return trx
            }

        // Prepare transaction
        let preparedTransactions = try transactions.map { (trx: Transaction) -> PreparedTransaction in
            PreparedTransaction(
                transaction: trx,
                signers: [try owner],
                expectedFee: fee
            )
        }

        // Relay transaction
        guard
            let preparedTransaction = preparedTransactions.first,
            transactions.count == 1
        else { throw SolendActionError.expectedOneTransaction }
        let ids = [try await feeRelay.relayTransaction(preparedTransaction)]

        // Listen last transaction
        guard let primaryTrxId = ids.last else { throw SolanaError.unknown }
        Task.detached(priority: .utility) { [self] in
            try await listenTransactionStatus(
                transactionID: primaryTrxId,
                initialAction: initialAction
            )
        }
    }

    func listenTransactionStatus(transactionID: TransactionID, initialAction: SolendAction) async throws {
        var action = initialAction
        action.transactionID = transactionID

        do {
            for try await status in solana.observeSignatureStatus(signature: transactionID) {
                let actionStatus: SolendActionStatus
                switch status {
                case .sending, .confirmed:
                    actionStatus = .processing
                case .finalized:
                    actionStatus = .success
                case let .error(msg):
                    actionStatus = .failed(msg: msg ?? "")
                }

                action.status = actionStatus
                currentActionSubject.send(action)

                if actionStatus == .success {
                    currentActionSubject.send(nil)
                    return
                }
            }
        }
    }

    public func getCurrentAction() -> SolendAction? {
        currentActionSubject.value
    }
}