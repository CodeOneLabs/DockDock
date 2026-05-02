import AppKit
import SwiftUI

struct ExclusionEditor: View {
    @ObservedObject var settings: AppSettings
    @State private var manualBundleID = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Exception apps")
                    .font(.headline)

                Spacer()

                Button("Add Frontmost") {
                    addFrontmostApp()
                }
            }

            Text("DockDock pauses while one of these apps is frontmost.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("com.example.App", text: $manualBundleID)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    settings.addExcludedBundleID(manualBundleID)
                    manualBundleID = ""
                }
                .disabled(manualBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if settings.excludedBundleIDs.isEmpty {
                Text("No exceptions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(displayName(for: bundleID))
                            Text(bundleID)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Button("Remove") {
                                settings.removeExcludedBundleID(bundleID)
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func addFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else {
            showMessage("No frontmost app to add.")
            return
        }

        if settings.excludedBundleIDs.contains(bundleID) {
            showMessage("\(app.localizedName ?? bundleID) is already excluded.")
            return
        }

        settings.addExcludedBundleID(bundleID)
        showMessage("Added \(app.localizedName ?? bundleID).")
    }

    private func showMessage(_ text: String) {
        message = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if message == text {
                message = nil
            }
        }
    }

    private func displayName(for bundleID: String) -> String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return "Unknown"
        }

        return appURL.deletingPathExtension().lastPathComponent
    }
}
