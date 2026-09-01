import SwiftUI

@main
struct CekrekApp: App {
    @StateObject private var settingsStore = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            CameraView()
                .environmentObject(settingsStore)
        }
    }
}
