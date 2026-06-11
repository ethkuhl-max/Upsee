import SwiftUI

struct LockScreenView: View {
    @Environment(LockManager.self) private var lockManager
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // Frosted backdrop hides whatever was underneath.
            Color.black.opacity(0.85).ignoresSafeArea()
            VisualEffectBackdrop().ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Upsee is locked")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Authenticate to view your portfolio, transactions, and decisions.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                Button {
                    Task { await tryUnlock() }
                } label: {
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: lockManager.biometryKind.systemImage)
                        }
                        Text(isAuthenticating ? "Authenticating…" : "Unlock with \(lockManager.biometryKind.displayName)")
                    }
                    .frame(minWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating)

                if let err = lockManager.lastAuthError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
            }
            .padding(40)
        }
        .task { await tryUnlock() }
    }

    private func tryUnlock() async {
        guard !isAuthenticating, !lockManager.isUnlocked else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        _ = await lockManager.authenticate()
    }
}

/// Thin NSVisualEffectView wrapper so the lock screen feels Mac-native.
private struct VisualEffectBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
