//
//  ThermalForgeApp.swift
//  ThermalForge
//
//  Menu bar app for fan control on Apple Silicon MacBooks.
//

import SwiftUI
import ThermalForgeCore

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Prevent duplicate instances
        let bundleID = Bundle.main.bundleIdentifier ?? "com.thermalforge.app"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            TFLogger.shared.error("Another instance already running — quitting")
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Reset fans on quit so the daemon doesn't hold stale APP settings — but
        // ONLY if the app owns the hold. A CLI hold (`sudo thermalforge max`) is the
        // user's deliberate, unsupervised choice; quitting the menu bar app must not
        // destroy it — that's the v0.1.7 arbitration feature. Synchronous on purpose:
        // the process is exiting, so an async write would be dropped; both calls are
        // bounded by the sendRaw timeout.
        let client = DaemonClient()
        if let state = try? client.readState(), state.owner == "app" {
            _ = try? client.execute(.resetAuto)
        }
        // owner == "cli" → leave the CLI hold alone; owner == "none" → nothing to reset.
    }
}

@main
struct ThermalForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            MenuBarLabel(
                state: appState.monitorState,
                maxTemp: appState.maxTemp,
                fahrenheit: appState.useFahrenheit,
                content: appState.menuBarContent
            )
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    let state: MonitorState
    let maxTemp: Float?
    var fahrenheit: Bool = false
    var content: MenuBarContent = .iconAndTemperature

    var body: some View {
        // MenuBarExtra copies a label's Text into the status item title and drops every
        // modifier on it, so digits come out proportional and the item's width jitters
        // as the number changes. A pre-rendered template image is the only form the
        // menu bar displays untouched.
        Image(nsImage: rendered)
    }

    private var rendered: NSImage {
        let renderer = ImageRenderer(content: label)
        renderer.scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }

    private var temperature: Float? { content.showsTemperature ? maxTemp : nil }

    /// Temperature-only still shows the icon when there is nothing to show yet, and
    /// during a safety override, so the item is never blank or silent.
    private var showsIcon: Bool {
        content != .temperatureOnly || temperature == nil || state == .safetyOverride
    }

    private var label: some View {
        HStack(spacing: 3) {
            if showsIcon {
                Image(systemName: iconName)
            }
            if let tempC = temperature {
                let display = fahrenheit ? tempC * 9 / 5 + 32 : tempC
                Text("\(Int(display))°")
                    .font(.system(size: 13).monospacedDigit())
            }
        }
        .foregroundStyle(.black)
    }

    private var iconName: String {
        switch state {
        case .safetyOverride: return "exclamationmark.triangle.fill"
        case .active: return "fan.fill"
        case .idle: return "fan"
        }
    }
}
