//
//  LaunchAtLogin.swift
//  kexp-menubar
//

import AppKit
import ServiceManagement

/// Registers the app as a macOS login item via `SMAppService.mainApp`.
/// The service status is the source of truth — the user can also flip this in
/// System Settings > General > Login Items, so nothing is cached locally.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @MainActor
    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                guard service.status != .enabled else { return }
                try service.register()
            } else {
                guard service.status != .notRegistered else { return }
                try service.unregister()
            }
            print("[LaunchAtLogin] \(enabled ? "registered" : "unregistered") (status: \(describe(service.status)))")
        } catch {
            print("[LaunchAtLogin] failed to \(enabled ? "register" : "unregister"): \(error.localizedDescription)")
            presentFailure(enabled: enabled, status: service.status)
        }
    }

    @MainActor
    private static func presentFailure(enabled: Bool, status: SMAppService.Status) {
        let alert = NSAlert()
        alert.alertStyle = .warning

        guard status != .requiresApproval else {
            alert.messageText = "Login Item Needs Approval"
            alert.informativeText =
                "macOS is blocking KEXP Menubar from starting at login. Turn it on under Login Items in System Settings."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
            return
        }

        alert.messageText = enabled
            ? "Couldn't Start KEXP Menubar at Login"
            : "Couldn't Stop KEXP Menubar from Starting at Login"
        alert.informativeText =
            "macOS refused the change. This usually means the app isn't code signed or isn't in /Applications."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
}
