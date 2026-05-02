import AppKit
import SwiftUI

@main
@MainActor
struct DockDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: AppSettings
    @StateObject private var service: DockTriggerService
    @StateObject private var overlay: TriggerBandOverlayService
    @StateObject private var launchAtLogin: LaunchAtLoginService

    init() {
        let settings = AppSettings()
        let service = DockTriggerService()
        let overlay = TriggerBandOverlayService()
        let launchAtLogin = LaunchAtLoginService()

        _settings = StateObject(wrappedValue: settings)
        _service = StateObject(wrappedValue: service)
        _overlay = StateObject(wrappedValue: overlay)
        _launchAtLogin = StateObject(wrappedValue: launchAtLogin)

        service.bind(settings: settings)
        launchAtLogin.askOnFirstLaunchIfNeeded(settings: settings)
    }

    var body: some Scene {
        MenuBarExtra("DockDock", systemImage: settings.isEnabled ? "dock.rectangle" : "dock.rectangle") {
            MenuBarControls(
                settings: settings,
                service: service,
                overlay: overlay,
                launchAtLogin: launchAtLogin
            )
        }
        .menuBarExtraStyle(.window)

        Window("DockDock", id: "settings") {
            ContentView(
                settings: settings,
                service: service,
                overlay: overlay,
                launchAtLogin: launchAtLogin
            )
        }
        .defaultSize(width: 720, height: 640)
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The event tap is process-owned and is removed automatically on exit.
    }
}
