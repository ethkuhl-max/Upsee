import SwiftUI
import SwiftData

@main
struct UpseeApp: App {
    @State private var lockManager = LockManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1200, minHeight: 760)
                .environment(lockManager)
                .overlay {
                    if !lockManager.isUnlocked {
                        LockScreenView()
                            .environment(lockManager)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: lockManager.isUnlocked)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase)
                }
        }
        .modelContainer(UpseeStore.modelContainer)
        .windowResizability(.contentSize)
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Re-lock when the window goes to background, if enabled.
            if lockManager.requireLockOnLaunch {
                lockManager.lock()
            }
        case .active:
            lockManager.recordActivity()
            lockManager.evaluateAutoLock()
        default:
            break
        }
    }
}
