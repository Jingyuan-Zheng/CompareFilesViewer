import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
@MainActor
struct CompareFilesViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup(L10n.ui("Compare Files")) {
            Group {
                if let payload = store.payload {
                    ContentView(payload: payload)
                } else {
                    ErrorView(message: store.errorMessage ?? L10n.ui("No displayable data was received."))
                }
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings { SettingsView() }
    }
}
