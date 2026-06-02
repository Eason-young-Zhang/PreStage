import AppKit
import SwiftUI

@main
struct PreStageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("PreStage") {
            ContentView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: store.appLanguage.localeIdentifier))
                .preferredColorScheme(store.panelLayout.appAppearance.colorScheme)
                .frame(minWidth: 1260, minHeight: 720)
        }
        .commands {
            AppCommands(store: store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: store.appLanguage.localeIdentifier))
                .preferredColorScheme(store.panelLayout.appAppearance.colorScheme)
                .frame(width: 420)
        }
    }
}

private extension AppAppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            self.configureMainWindows()
            self.openMainWindowIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindowIfNeeded()
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureMainWindows()
        openMainWindowIfNeeded()
    }

    func applicationDidUpdate(_ notification: Notification) {
        configureMainWindows()
    }

    private func openMainWindowIfNeeded() {
        guard !NSApp.windows.contains(where: { $0.isVisible }) else { return }
        if let existingWindow = mainWindows.first {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
        DispatchQueue.main.async {
            self.configureMainWindows()
        }
    }

    private var mainWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window.title == "PreStage" || window.contentViewController != nil
        }
    }

    private func configureMainWindows() {
        for window in mainWindows {
            window.isReleasedWhenClosed = false
        }
    }
}
