import SwiftUI
import SwiftData

@main
struct UpseeApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1200, minHeight: 760)
        }
        .modelContainer(UpseeStore.modelContainer)
        .windowResizability(.contentSize)
    }
}
