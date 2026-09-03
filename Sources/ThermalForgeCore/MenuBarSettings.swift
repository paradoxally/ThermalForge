//
//  MenuBarSettings.swift
//  ThermalForge
//
//  What the menu bar item shows and which sensor drives its temperature.
//

import Foundation

public enum MenuBarContent: String, CaseIterable, Sendable {
    case iconOnly
    case iconAndTemperature
    case temperatureOnly

    public var title: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .iconAndTemperature: return "Icon + temperature"
        case .temperatureOnly: return "Temperature only"
        }
    }

    public var showsTemperature: Bool { self != .iconOnly }

    /// Resolves a persisted raw value; anything unknown keeps the pre-setting behaviour.
    public static func stored(_ raw: String?) -> MenuBarContent {
        raw.flatMap(MenuBarContent.init(rawValue:)) ?? .iconAndTemperature
    }
}

public enum MenuBarSensor: String, CaseIterable, Sendable {
    case cpuGPU
    case cpu
    case gpu
    case ssd

    public var title: String {
        switch self {
        case .cpuGPU: return "CPU + GPU"
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .ssd: return "SSD"
        }
    }

    /// SMC key prefixes, matching the dropdown's temperature rows.
    public var prefixes: [String] {
        switch self {
        case .cpuGPU: return MenuBarSensor.cpu.prefixes + MenuBarSensor.gpu.prefixes
        case .cpu: return ["TC", "Tp"]
        case .gpu: return ["TG", "Tg"]
        case .ssd: return ["TH"]
        }
    }

    /// Resolves a persisted raw value; anything unknown keeps the pre-setting behaviour.
    public static func stored(_ raw: String?) -> MenuBarSensor {
        raw.flatMap(MenuBarSensor.init(rawValue:)) ?? .cpuGPU
    }
}

extension ThermalStatus {
    /// Hottest reading among sensors whose key starts with one of `prefixes`.
    public func peakTemperature(prefixes: [String]) -> Float? {
        temperatures
            .filter { key, _ in prefixes.contains(where: { key.hasPrefix($0) }) }
            .values.max()
    }
}
