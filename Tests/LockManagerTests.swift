import XCTest
@testable import Upsee

@MainActor
final class LockManagerTests: XCTestCase {
    func testAutoLockNoOpsWhenDisabled() {
        let lm = LockManager.shared
        lm.isUnlocked = true
        lm.autoLockMinutes = 0
        lm.evaluateAutoLock()
        XCTAssertTrue(lm.isUnlocked)
    }

    func testAutoLockTriggersAfterTimeout() {
        let lm = LockManager.shared
        lm.isUnlocked = true
        lm.autoLockMinutes = 1
        // Force lastActivityAt to 2 minutes ago by simulating "now" in the future.
        let future = Date().addingTimeInterval(120)
        lm.evaluateAutoLock(now: future)
        XCTAssertFalse(lm.isUnlocked)
    }

    func testManualLock() {
        let lm = LockManager.shared
        lm.isUnlocked = true
        lm.lock()
        XCTAssertFalse(lm.isUnlocked)
    }

    func testPrivacyModeToggle() {
        let lm = LockManager.shared
        let initial = lm.isPrivacyMode
        lm.togglePrivacyMode()
        XCTAssertNotEqual(initial, lm.isPrivacyMode)
        lm.togglePrivacyMode() // restore
    }

    func testSectionLockToggle() {
        let lm = LockManager.shared
        // Cleanup any prior state from earlier test runs.
        lm.lockedSectionRawValues = []
        XCTAssertFalse(lm.isSectionLocked("wealth"))
        lm.toggleSectionLock("wealth")
        XCTAssertTrue(lm.isSectionLocked("wealth"))
        lm.toggleSectionLock("wealth")
        XCTAssertFalse(lm.isSectionLocked("wealth"))
    }

    func testRecordActivityResetsClock() {
        let lm = LockManager.shared
        lm.isUnlocked = true
        lm.autoLockMinutes = 1
        // Far-future: would normally lock. But record activity first.
        lm.recordActivity()
        let nearFuture = Date().addingTimeInterval(30) // 30s — below threshold
        lm.evaluateAutoLock(now: nearFuture)
        XCTAssertTrue(lm.isUnlocked)
    }
}
