import Foundation
import Observation
import LocalAuthentication

/// Single source of truth for app-wide lock and privacy state. Observable so
/// any view that reads `isUnlocked` or `isPrivacyMode` re-renders when state
/// changes — that's what makes the currency-masking helper work transparently.
@MainActor
@Observable
final class LockManager {
    static let shared = LockManager()

    /// True when the UI should be visible. False shows the lock screen.
    var isUnlocked: Bool

    /// When true, dollar amounts are masked in the UI without requiring a full unlock.
    /// Useful for "show me the screen but not the numbers" — coffee shop, screen share.
    var isPrivacyMode: Bool

    /// Last user-initiated activity. Used by the auto-lock timer.
    private(set) var lastActivityAt: Date = Date()

    /// Last auth failure reason, surfaced on the lock screen.
    var lastAuthError: String?

    /// Whether the device can do biometric auth at all (Touch ID on Mac, Face ID on iPhone).
    let canUseBiometrics: Bool
    /// Specific biometry kind for UI labeling.
    let biometryKind: BiometryKind

    // MARK: - UserDefaults-backed settings

    private let userDefaults = UserDefaults.standard

    var requireLockOnLaunch: Bool {
        get { userDefaults.object(forKey: "lock.requireOnLaunch") as? Bool ?? false }
        set { userDefaults.set(newValue, forKey: "lock.requireOnLaunch") }
    }

    /// 0 = never auto-lock. Otherwise minutes of inactivity before auto-lock.
    var autoLockMinutes: Int {
        get { userDefaults.object(forKey: "lock.autoLockMinutes") as? Int ?? 0 }
        set { userDefaults.set(newValue, forKey: "lock.autoLockMinutes") }
    }

    var privacyModeOnLaunch: Bool {
        get { userDefaults.object(forKey: "lock.privacyOnLaunch") as? Bool ?? false }
        set { userDefaults.set(newValue, forKey: "lock.privacyOnLaunch") }
    }

    /// Set of UpseeSection raw values that always require unlock to view, even
    /// if the rest of the app is in soft-unlocked state. Used for granular lock.
    var lockedSectionRawValues: Set<String> {
        get { Set(userDefaults.array(forKey: "lock.sections") as? [String] ?? []) }
        set { userDefaults.set(Array(newValue), forKey: "lock.sections") }
    }

    init() {
        let context = LAContext()
        var err: NSError?
        let canDo = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
        self.canUseBiometrics = canDo
        switch context.biometryType {
        case .touchID: self.biometryKind = .touchID
        case .faceID: self.biometryKind = .faceID
        case .opticID: self.biometryKind = .opticID
        default: self.biometryKind = .none
        }
        // Initial unlock state derives from requireLockOnLaunch + ability to auth.
        let requireLock = userDefaults.object(forKey: "lock.requireOnLaunch") as? Bool ?? false
        self.isUnlocked = !requireLock
        let privacy = userDefaults.object(forKey: "lock.privacyOnLaunch") as? Bool ?? false
        self.isPrivacyMode = privacy
    }

    // MARK: - Public actions

    func recordActivity() {
        lastActivityAt = Date()
    }

    func lock() {
        isUnlocked = false
        lastAuthError = nil
    }

    func togglePrivacyMode() {
        isPrivacyMode.toggle()
    }

    func toggleSectionLock(_ sectionRaw: String) {
        var set = lockedSectionRawValues
        if set.contains(sectionRaw) { set.remove(sectionRaw) } else { set.insert(sectionRaw) }
        lockedSectionRawValues = set
    }

    func isSectionLocked(_ sectionRaw: String) -> Bool {
        lockedSectionRawValues.contains(sectionRaw)
    }

    /// Drives auto-lock from a periodic timer. No-op if autoLockMinutes == 0
    /// or the app is already locked.
    func evaluateAutoLock(now: Date = Date()) {
        guard isUnlocked, autoLockMinutes > 0 else { return }
        let elapsed = now.timeIntervalSince(lastActivityAt)
        if elapsed >= Double(autoLockMinutes * 60) {
            lock()
        }
    }

    /// Trigger biometric / password auth.
    @discardableResult
    func authenticate(reason: String = "Unlock Upsee") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"
        var policyError: NSError?
        let policy: LAPolicy = canUseBiometrics
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &policyError) else {
            lastAuthError = policyError?.localizedDescription ?? "Authentication unavailable"
            return false
        }
        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                isUnlocked = true
                lastAuthError = nil
                recordActivity()
            }
            return success
        } catch let error as LAError where error.code == .userCancel {
            // Don't show an error for user-initiated cancel.
            return false
        } catch {
            lastAuthError = error.localizedDescription
            return false
        }
    }
}

enum BiometryKind {
    case touchID
    case faceID
    case opticID
    case none

    var displayName: String {
        switch self {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        case .none: return "Password"
        }
    }

    var systemImage: String {
        switch self {
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        case .none: return "key"
        }
    }
}
