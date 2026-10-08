import Foundation
import Observation
import Security
import StoreKit

/// One-off £4.99 unlock after a free trial. No subscriptions, no ads.
@MainActor
@Observable
final class PurchaseManager {
    static let productID = "com.mattlakin.ShiftCalendar.fullunlock"
    static let trialDays = 30

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isPurchasing = false
    var message: String?

    @ObservationIgnored private var trialStart: Date
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Bumped to make views re-read trial days (e.g. after the debug reset).
    private var trialVersion = 0

    init() {
        trialStart = TrialClock.startDate()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task { await load() }
    }

    var daysLeftInTrial: Int {
        _ = trialVersion
        let used = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
        return max(0, Self.trialDays - used)
    }

    var hasAccess: Bool { isUnlocked || daysLeftInTrial > 0 }

    /// "£4.99" from the App Store, or a sensible fallback before it loads.
    var priceText: String { product?.displayPrice ?? "£4.99" }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isUnlocked = owned
    }

    func buy() async {
        if product == nil { await load() }
        guard let product else {
            message = "Couldn't reach the App Store. Check you're online and try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isUnlocked = true
                    message = "Unlocked. Thank you!"
                } else {
                    message = "The App Store couldn't confirm that purchase. Try Restore Purchase."
                }
            case .pending:
                message = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        try? await StoreKit.AppStore.sync()
        await refreshEntitlements()
        message = isUnlocked ? "Purchase restored. Thank you!" : "No previous purchase found for this Apple ID."
    }

    #if DEBUG
    /// Lets you see the paywall without waiting a month.
    func debugEndTrial() {
        trialStart = Calendar.current.date(byAdding: .day, value: -(Self.trialDays + 1), to: Date())!
        TrialClock.save(trialStart)
        trialVersion += 1
    }

    func debugRestartTrial() {
        trialStart = Date()
        TrialClock.save(trialStart)
        trialVersion += 1
    }
    #endif
}

/// Remembers when the free trial started. Kept in the Keychain so deleting and
/// reinstalling the app doesn't restart the trial.
enum TrialClock {
    private static let account = "trialStart"
    private static let service = "com.mattlakin.ShiftCalendar"

    static func startDate() -> Date {
        if let saved = load() { return saved }
        let now = Date()
        save(now)
        return now
    }

    private static func load() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let seconds = Double(String(decoding: data, as: UTF8.self))
        else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func save(_ date: Date) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(String(date.timeIntervalSince1970).utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}
