import SwiftUI
import ApplicationServices

@main
struct KeyTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updater = UpdaterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 460)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
        .commands {
            CheckForUpdatesCommand(updater: updater)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        // Trigger the Accessibility permission prompt on first launch.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
