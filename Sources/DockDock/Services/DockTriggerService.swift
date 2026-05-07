import ApplicationServices
import AppKit
import Combine
import CoreGraphics
import DockDockCore
import Foundation

@MainActor
final class DockTriggerService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSnapDescription = "No snaps yet"
    @Published private(set) var activeExclusionDescription: String?
    @Published private(set) var hasAccessibilityPermission = AccessibilityPermission.isTrusted

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var settings: AppSettings?
    private let runtime = DockTriggerRuntime()
    private var permissionTimer: Timer?
    private var settingsCancellables = Set<AnyCancellable>()
    private var appActivationObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?

    func bind(settings: AppSettings) {
        self.settings = settings
        bindSettings(settings)
        startWorkspaceMonitor()
        startScreenMonitor()
        refreshRuntimeConfiguration()
        startPermissionMonitor()
        restart()
    }

    deinit {
        permissionTimer?.invalidate()
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    func restart() {
        stop()

        guard let settings, settings.isEnabled else {
            lastError = nil
            return
        }

        refreshPermission()
        guard hasAccessibilityPermission else {
            lastError = "Accessibility permission is required before DockDock can monitor mouse movement."
            return
        }

        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        let unmanagedRuntime = Unmanaged.passUnretained(runtime).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: DockTriggerService.eventCallback,
            userInfo: unmanagedRuntime
        ) else {
            lastError = "Could not create the mouse event tap. Recheck Accessibility/Input Monitoring permission."
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        runtime.resetState()
        refreshRuntimeConfiguration()
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        lastError = nil
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
        isRunning = false
        runtime.resetState()
    }

    func refreshPermission() {
        hasAccessibilityPermission = AccessibilityPermission.isTrusted
    }

    func requestPermission() {
        AccessibilityPermission.request()
        refreshPermission()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            refreshPermission()
            if hasAccessibilityPermission {
                restart()
            }
        }
    }

    private func startPermissionMonitor() {
        guard permissionTimer == nil else {
            return
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPermission()
            }
        }
    }

    private func pollPermission() {
        let wasTrusted = hasAccessibilityPermission
        refreshPermission()

        guard wasTrusted != hasAccessibilityPermission else {
            return
        }

        if hasAccessibilityPermission {
            restart()
        } else {
            stop()
            lastError = "Accessibility permission is required before DockDock can monitor mouse movement."
        }
    }

    private nonisolated static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard type == .mouseMoved, let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let runtime = Unmanaged<DockTriggerRuntime>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

        if let snap = runtime.handleMouseMoved(to: event.location) {
            CGWarpMouseCursorPosition(snap.point)
            Task { @MainActor in
                DockTriggerService.handleCompletedSnap(snap)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private static weak var activeService: DockTriggerService?

    private static func handleCompletedSnap(_ snap: DockTriggerSnap) {
        guard let service = activeService else {
            return
        }

        if snap.shouldPlaySound {
            SnapSoundService.play()
        }
        service.lastSnapDescription = "Snapped to \(Int(snap.point.x)), \(Int(snap.point.y))"
    }

    private func bindSettings(_ settings: AppSettings) {
        settingsCancellables.removeAll()

        settings.$isEnabled
            .sink { [weak self] _ in self?.refreshRuntimeConfiguration() }
            .store(in: &settingsCancellables)
        settings.$activationBand
            .sink { [weak self] _ in self?.refreshRuntimeConfiguration() }
            .store(in: &settingsCancellables)
        settings.$dockEdge
            .sink { [weak self] _ in self?.refreshRuntimeConfiguration() }
            .store(in: &settingsCancellables)
        settings.$isSnapSoundEnabled
            .sink { [weak self] _ in self?.refreshRuntimeConfiguration() }
            .store(in: &settingsCancellables)
        settings.$excludedBundleIDs
            .sink { [weak self] _ in self?.refreshRuntimeConfiguration() }
            .store(in: &settingsCancellables)
    }

    private func startWorkspaceMonitor() {
        guard appActivationObserver == nil else {
            return
        }

        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRuntimeConfiguration()
            }
        }
    }

    private func startScreenMonitor() {
        guard screenParametersObserver == nil else {
            return
        }

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRuntimeConfiguration()
            }
        }
    }

    private func refreshRuntimeConfiguration() {
        guard let settings else {
            runtime.updateConfiguration(DockTriggerRuntimeConfiguration())
            return
        }

        let excludedApp = frontmostExcludedApp(settings: settings)
        activeExclusionDescription = excludedApp.map { "Paused for \($0)" }
        runtime.updateConfiguration(
            DockTriggerRuntimeConfiguration(
                isEnabled: settings.isEnabled,
                activationBand: CGFloat(settings.activationBand),
                dockEdge: settings.dockEdge,
                isSnapSoundEnabled: settings.isSnapSoundEnabled,
                isFrontmostAppExcluded: excludedApp != nil,
                dockDisplay: DisplayGeometry.dockDisplayTarget(edge: settings.dockEdge)
            )
        )
        Self.activeService = self
    }

    private func frontmostExcludedApp(settings: AppSettings) -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              settings.excludedBundleIDs.contains(bundleID) else {
            return nil
        }

        return app.localizedName ?? bundleID
    }
}
