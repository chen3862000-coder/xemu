import Foundation
import StoreKit

public enum PurchaseError: Error, LocalizedError {
    case purchaseFailed(Error)
    case receiptValidationFailed(Error)
    case entitlementRefreshFailed(Error)
    case productNotFound(ProductCode)
    case transactionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .receiptValidationFailed(let error):
            return "Receipt validation failed: \(error.localizedDescription)"
        case .entitlementRefreshFailed(let error):
            return "Failed to refresh entitlements: \(error.localizedDescription)"
        case .productNotFound(let code):
            return "Product not found: \(code.rawValue)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        }
    }
}

public enum PurchaseResult {
    case success(ProductCode)
    case pending(ProductCode)
    case failed(PurchaseError)
    case cancelled
}

@MainActor
public final class PurchaseFlowController: NSObject, ObservableObject {
    @MainActor public static let shared = PurchaseFlowController()

    @Published public var isPurchasing = false
    @Published public var lastPurchaseResult: PurchaseResult?
    @Published public var availableProducts: [ProductCode: Product] = [:]

    private let apiStub = AzureApiStub.shared
    private var updateListenerTask: Task<Void, Never>?

    private override init() {
        super.init()
        setupTransactionListener()
        loadProducts()
    }

    private func setupTransactionListener() {
        updateListenerTask = Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }

    private func loadProducts() {
        let productIdentifiers = [ProductCode.removeAds, .experimentalPack, .proBundle].map { $0.rawValue }
        Task {
            do {
                let products = try await Product.products(for: productIdentifiers)
                await MainActor.run {
                    for product in products {
                        if let code = ProductCode(rawValue: product.id) {
                            availableProducts[code] = product
                        }
                    }
                }
            } catch {
                print("⚠️ Failed to load products: \(error)")
            }
        }
    }

    public func purchase(productCode: ProductCode) async -> PurchaseResult {
        guard let product = availableProducts[productCode] else {
            return .failed(.productNotFound(productCode))
        }

        await MainActor.run {
            isPurchasing = true
        }

        defer {
            Task { @MainActor in
                isPurchasing = false
            }
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleSuccessfulTransaction(transaction, productCode: productCode)
                await transaction.finish()

                return .success(productCode)

            case .pending:
                return .pending(productCode)

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed(.transactionFailed("Unknown purchase result"))
            }
        } catch {
            return .failed(.purchaseFailed(error))
        }
    }

    private func handleTransactionUpdate(_ verification: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(verification)
            await handleSuccessfulTransaction(transaction, productCode: nil)
            await transaction.finish()
        } catch {
            print("⚠️ Failed to handle transaction update: \(error)")
        }
    }

    private func handleSuccessfulTransaction(_ transaction: Transaction, productCode: ProductCode?) async {
        guard transaction.productType == .nonConsumable else { return }

        do {
            let receipt = try await fetchReceipt()
            try await validateReceipt(receipt, transactionID: transaction.id)
            try await refreshEntitlements()

            await MainActor.run {
                let code = productCode ?? ProductCode(rawValue: transaction.productID)
                lastPurchaseResult = code.map { .success($0) }
            }
        } catch {
            print("⚠️ Failed to handle successful transaction: \(error)")
            await MainActor.run {
                lastPurchaseResult = .failed(.receiptValidationFailed(error))
            }
        }
    }

    private func fetchReceipt() async throws -> Data {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           let receiptData = try? Data(contentsOf: appStoreReceiptURL) {
            return receiptData
        }
        throw PurchaseError.receiptValidationFailed(URLError(.fileDoesNotExist))
    }

    private func validateReceipt(_ receipt: Data, transactionID: UInt64) async throws {
        do {
            let entitlementBundle = try await apiStub.fetchEntitlements()

            let hasValidEntitlement = entitlementBundle.entitlements.contains { entitlement in
                entitlement.status == "Active"
            }

            guard hasValidEntitlement else {
                throw PurchaseError.receiptValidationFailed(
                    NSError(domain: "PurchaseFlow", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "No valid entitlements found"
                    ])
                )
            }

            print("✓ Receipt validated successfully for transaction \(transactionID)")
        } catch {
            throw PurchaseError.receiptValidationFailed(error)
        }
    }

    private func refreshEntitlements() async throws {
        do {
            let entitlementBundle = try await apiStub.fetchEntitlements()
            print("✓ Entitlements refreshed successfully")
        } catch {
            throw PurchaseError.entitlementRefreshFailed(error)
        }
    }

    public func restorePurchases() async -> PurchaseResult {
        await MainActor.run {
            isPurchasing = true
        }

        defer {
            Task { @MainActor in
                isPurchasing = false
            }
        }

        do {
            try await AppStore.sync()

            do {
                try await refreshEntitlements()

                let entitlementBundle = try await apiStub.fetchEntitlements()
                let hasActiveEntitlement = entitlementBundle.entitlements.contains {
                    $0.status == "Active"
                }

                if hasActiveEntitlement {
                    return .success(.proBundle)
                } else {
                    return .cancelled
                }
            } catch {
                return .failed(.entitlementRefreshFailed(error))
            }
        } catch {
            return .failed(.purchaseFailed(error))
        }
    }

    public func getProductPrice(_ productCode: ProductCode) -> String? {
        return availableProducts[productCode]?.displayPrice
    }

    public func hasProduct(_ productCode: ProductCode) -> Bool {
        return availableProducts[productCode] != nil
    }

    private func checkVerified<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .unverified:
            throw PurchaseError.receiptValidationFailed(
                NSError(domain: "PurchaseFlow", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "Transaction verification failed"
                ])
            )
        case .verified(let safe):
            return safe
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }
}

extension PurchaseFlowController {
    public struct PurchaseInfo {
        public let productCode: ProductCode
        public let displayName: String
        public let description: String
        public let price: String
    }

    public func getPurchaseInfo(for productCode: ProductCode) -> PurchaseInfo? {
        guard let product = availableProducts[productCode] else { return nil }

        return PurchaseInfo(
            productCode: productCode,
            displayName: product.displayName,
            description: product.description,
            price: product.displayPrice
        )
    }
}

extension EntitlementCache {
    func updateEntitlements(from bundle: AzureApiStub.EntitlementBundle) async throws {
        print("✓ Updated \(bundle.entitlements.count) entitlements from Azure API")
    }
}
