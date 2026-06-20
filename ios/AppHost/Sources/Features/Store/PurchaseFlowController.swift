import Foundation
import OSLog
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

    private let entitlementCache = EntitlementCache.shared
    private let logger = Logger(subsystem: "com.xemu.app", category: "PurchaseFlow")
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
                logger.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
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
                let activatedCode = try await handleSuccessfulTransaction(transaction, productCode: productCode)
                await transaction.finish()

                return .success(activatedCode)

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
            _ = try await handleSuccessfulTransaction(transaction, productCode: nil)
            await transaction.finish()
        } catch {
            logger.error("Failed to handle transaction update: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleSuccessfulTransaction(_ transaction: Transaction, productCode: ProductCode?) async throws -> ProductCode {
        guard transaction.productType == .nonConsumable else {
            throw PurchaseError.transactionFailed("Unsupported transaction type")
        }

        let bundle = try await syncEntitlementsFromStoreKit()
        guard let code = productCode ?? ProductCode(rawValue: transaction.productID) else {
            let error = PurchaseError.receiptValidationFailed(
                NSError(
                    domain: "PurchaseFlow",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Transaction product is not mapped to a known entitlement."]
                )
            )
            await MainActor.run {
                lastPurchaseResult = .failed(error)
            }
            throw error
        }

        guard bundle.entitlements.contains(where: { $0.productCode == code && $0.status == .active }) else {
            let error = PurchaseError.receiptValidationFailed(
                NSError(
                    domain: "PurchaseFlow",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Verified transaction did not produce an active entitlement."]
                )
            )
            await MainActor.run {
                lastPurchaseResult = .failed(error)
            }
            throw error
        }

        await MainActor.run {
            lastPurchaseResult = .success(code)
        }
        return code
    }

    private func syncEntitlementsFromStoreKit() async throws -> EntitlementBundle {
        var entitlements: [Entitlement] = []

        for await result in Transaction.currentEntitlements {
            let transaction = try checkVerified(result)
            guard let productCode = ProductCode(rawValue: transaction.productID) else { continue }

            let status: EntitlementStatus
            if transaction.revocationReason != nil {
                status = .revoked
            } else if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                status = .expired
            } else {
                status = .active
            }

            entitlements.append(
                Entitlement(
                    entitlementId: UUID(),
                    productCode: productCode,
                    status: status,
                    activatedAt: transaction.purchaseDate,
                    expiresAt: transaction.expirationDate
                )
            )
        }

        let bundle = EntitlementBundle(
            userId: entitlementCache.getCachedBundle()?.userId ?? UUID(),
            entitlements: entitlements,
            deviceProfile: entitlementCache.getCachedDeviceProfile()
        )
        entitlementCache.cache(bundle)
        return bundle
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
            let bundle = try await syncEntitlementsFromStoreKit()
            let activeEntitlements = bundle.entitlements.filter { $0.status == .active }

            if activeEntitlements.contains(where: { $0.productCode == .proBundle }) {
                return .success(.proBundle)
            }
            if activeEntitlements.contains(where: { $0.productCode == .removeAds }) {
                return .success(.removeAds)
            }
            if let firstActive = activeEntitlements.first {
                return .success(firstActive.productCode)
            }
            return .cancelled
        } catch {
            return .failed(.entitlementRefreshFailed(error))
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
