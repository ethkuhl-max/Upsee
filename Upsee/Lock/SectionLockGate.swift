import SwiftUI

/// Per-section soft lock. Shown inline inside the detail pane when a user has
/// marked a specific section as locked-by-default (e.g., always require auth
/// to see Wealth or Transactions). Distinct from the app-wide lock screen.
struct SectionLockGate<Content: View>: View {
    let sectionRawValue: String
    let sectionLabel: String
    @ViewBuilder var content: () -> Content

    @Environment(LockManager.self) private var lockManager
    @State private var sectionUnlocked: Bool = false
    @State private var isAuthenticating = false

    private var isLocked: Bool {
        lockManager.isSectionLocked(sectionRawValue) && !sectionUnlocked
    }

    var body: some View {
        if isLocked {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.blue.opacity(0.8))
                Text("\(sectionLabel) is locked")
                    .font(.title3.weight(.semibold))
                Text("This section requires authentication to view. Configure in Lock & Privacy settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button {
                    Task { await tryUnlock() }
                } label: {
                    HStack {
                        if isAuthenticating { ProgressView().controlSize(.small) }
                        else { Image(systemName: lockManager.biometryKind.systemImage) }
                        Text("Unlock \(sectionLabel)")
                    }
                    .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content()
        }
    }

    private func tryUnlock() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        let ok = await lockManager.authenticate(reason: "Unlock \(sectionLabel)")
        if ok {
            sectionUnlocked = true
        }
    }
}
