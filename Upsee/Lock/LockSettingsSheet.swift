import SwiftUI

struct LockSettingsSheet: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(\.dismiss) private var dismiss

    @State private var requireOnLaunch: Bool = false
    @State private var autoLockMinutes: Int = 0
    @State private var privacyOnLaunch: Bool = false

    private let autoLockChoices: [(Int, String)] = [
        (0, "Never"),
        (1, "1 min"),
        (5, "5 min"),
        (15, "15 min"),
        (30, "30 min"),
        (60, "1 hr"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill").foregroundStyle(Color.blue).font(.title2)
                Text("Lock & Privacy").font(.title3.weight(.semibold))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Require unlock on launch", isOn: $requireOnLaunch).toggleStyle(.switch)
                Text("On launch, Upsee starts locked. Authenticate with \(lockManager.biometryKind.displayName) to view.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Auto-lock after inactivity").font(.callout.weight(.medium))
                    Spacer()
                    Picker("", selection: $autoLockMinutes) {
                        ForEach(autoLockChoices, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                Text("Locks Upsee after this much inactivity. Set to Never to disable.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Start in privacy mode (mask amounts)", isOn: $privacyOnLaunch).toggleStyle(.switch)
                Text("Privacy mode hides dollar values throughout the app without locking it. Toggle at any time from the sidebar.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: lockManager.canUseBiometrics ? "checkmark.shield" : "exclamationmark.shield")
                    .foregroundStyle(lockManager.canUseBiometrics ? Color.green : Color.orange)
                Text(lockManager.canUseBiometrics
                     ? "This Mac supports \(lockManager.biometryKind.displayName)."
                     : "This Mac doesn't have biometric auth — your account password will be used.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))

            Spacer()

            HStack {
                Button("Lock now") {
                    save()
                    lockManager.lock()
                    dismiss()
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 460)
        .onAppear {
            requireOnLaunch = lockManager.requireLockOnLaunch
            autoLockMinutes = lockManager.autoLockMinutes
            privacyOnLaunch = lockManager.privacyModeOnLaunch
        }
    }

    private func save() {
        lockManager.requireLockOnLaunch = requireOnLaunch
        lockManager.autoLockMinutes = autoLockMinutes
        lockManager.privacyModeOnLaunch = privacyOnLaunch
    }
}
