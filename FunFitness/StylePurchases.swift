//
//  StylePurchases.swift
//  FunFitness
//
//  The one in-app purchase for 3.3: "Unlock all styles" (non-consumable), which unlocks every Style
//  now, including Styles added later (Jay, 2026-11-15). StoreKit 2: ownership comes from verified
//  `Transaction.currentEntitlements`, so it restores on every device on the same Apple Account and
//  nothing is stored by the app. TestFlight uses the sandbox (free); on the App Store Jay redeems a
//  free offer code.
//

import Foundation
import StoreKit
import Observation
import os

@MainActor
@Observable
final class StylePurchases {
    static let shared = StylePurchases()

    /// Must match the product created in App Store Connect (and any StoreKit configuration file).
    static let unlockAllProductID = "com.jaytjones.FunFitness.styles.all"

    enum PurchaseResult: Equatable {
        case purchased
        case pending      // e.g. Ask to Buy
        case cancelled
        case failed
    }

    private(set) var ownsAllStyles = false
    /// nil until loaded, or if the product isn't available (not set up yet, offline).
    private(set) var product: Product?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.jaytjones.FunFitness", category: "Purchases")

    private init() {}

    /// Call once at launch: listens for purchases made elsewhere (another device, offer code
    /// redemption, Ask to Buy approval, refunds) and checks current ownership.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    func refreshEntitlements() async {
        var owns = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.unlockAllProductID,
               transaction.revocationDate == nil {
                owns = true
            }
        }
        ownsAllStyles = owns
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.unlockAllProductID]).first
        } catch {
            logger.error("Couldn't load the style product: \(String(describing: error), privacy: .public)")
        }
    }

    func purchase() async -> PurchaseResult {
        if product == nil { await loadProduct() }
        guard let product else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            logger.error("Style purchase failed: \(String(describing: error), privacy: .public)")
            return .failed
        }
    }

    /// "Restore Purchases": syncs with the App Store (may ask the person to sign in), then rechecks.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restore failed: \(String(describing: error), privacy: .public)")
        }
        await refreshEntitlements()
    }
}
