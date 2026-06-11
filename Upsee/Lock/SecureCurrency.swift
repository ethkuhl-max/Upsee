import Foundation
import SwiftUI

/// Privacy-mode-aware currency formatter. Use anywhere a dollar amount appears
/// that should be hidden when the user toggles privacy mode (coffee shop,
/// screen-share, presentation). Existing `currency()` calls can be migrated
/// incrementally — every replacement immediately benefits.
@MainActor
func currencyMasked(_ d: Decimal) -> String {
    if LockManager.shared.isPrivacyMode { return "••••" }
    return currency(d)
}

/// SwiftUI view variant for inline use where a Text() is needed. Observes
/// LockManager directly so privacy-mode toggles trigger re-renders even in
/// views that don't otherwise read the manager.
struct SecureAmount: View {
    let amount: Decimal
    var tint: Color = .primary
    var font: Font = .callout.monospacedDigit()

    @Environment(LockManager.self) private var lockManager

    var body: some View {
        Text(lockManager.isPrivacyMode ? "••••" : currency(amount))
            .font(font)
            .foregroundStyle(tint)
    }
}
