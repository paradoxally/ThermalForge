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
        // A template image is forced monochrome; the alert has to stay red.
        image.isTemplate = !isAlert
        return image
    }

    private var isAlert: Bool { state == .safetyOverride }

    private var temperature: Float? { content.showsTemperature ? maxTemp : nil }

    /// Temperature-only shows the icon only until the first reading arrives. The alert
    /// is signalled by colour, not by adding an icon, so it can't widen the item.
    private var showsIcon: Bool {
        content != .temperatureOnly || temperature == nil
    }

    private static let iconNames = ["fan", "fan.fill", "exclamationmark.triangle.fill"]

    private var label: some View {
        HStack(spacing: 3) {
            if showsIcon {
                iconSlot
            }
            if let temperatureText {
                temperatureSlot(temperatureText)
            }
        }
        .foregroundStyle(isAlert ? Color.red : Color.black)
    }

    private var temperatureText: String? {
        guard let tempC = temperature else { return nil }
        let display = fahrenheit ? tempC * 9 / 5 + 32 : tempC
        return "\(Int(display))°"
    }

    /// Always three digits wide, so crossing 100° can't widen the item. Centred, so a
    /// two-digit reading splits the spare room across both sides instead of leaving a
    /// gap on one.
    private func temperatureSlot(_ text: String) -> some View {
        let font = Font.system(size: 13).monospacedDigit()
        return ZStack {
            Text("000°").font(font).hidden()
            Text(text).font(font)
        }
    }

    /// Sized to the widest symbol so swapping fan for the alert triangle can't shift the digits.
    private var iconSlot: some View {
        ZStack {
            ForEach(Self.iconNames, id: \.self) { Image(systemName: $0).hidden() }
            Image(systemName: iconName)
        }
    }

    private var iconName: String {
        switch state {
        case .safetyOverride: return "exclamationmark.triangle.fill"
        case .active: return "fan.fill"
        case .idle: return "fan"
        }
    }
}
