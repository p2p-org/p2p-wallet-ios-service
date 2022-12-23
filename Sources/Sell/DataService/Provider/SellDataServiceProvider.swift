import Foundation

public protocol SellDataServiceProvider {
    associatedtype Transaction: ProviderTransaction
    associatedtype Currency: ProviderCurrency

    func sellTransactions(externalTransactionId: String) async throws -> [Transaction]
    func detailSellTransaction(id: String) async throws -> Transaction
    func deleteSellTransaction(id: String) async throws
}
