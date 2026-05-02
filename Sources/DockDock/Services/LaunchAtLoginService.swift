import AppKit
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var lastError: String?

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            lastError = nil
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func askOnFirstLaunchIfNeeded(settings: AppSettings) {
        guard !settings.hasAskedLaunchAtLogin else {
            return
        }

        settings.hasAskedLaunchAtLogin = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard SMAppService.mainApp.status != .enabled else {
                refresh()
                return
            }

            let alert = NSAlert()
            alert.messageText = "Start DockDock at login?"
            alert.informativeText = "DockDock works best as a background menu bar helper. You can change this later in Settings."
            alert.addButton(withTitle: "Start at Login")
            alert.addButton(withTitle: "Not Now")

            if alert.runModal() == .alertFirstButtonReturn {
                setEnabled(true)
            }
        }
    }
}
