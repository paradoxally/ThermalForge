//
//  MenuBarSensorTests.swift
//  ThermalForge
//
//  Which sensor drives the menu bar temperature, and how the choice persists.
//

import Testing

@testable import ThermalForgeCore

@Suite("Menu bar sensor selection")
struct MenuBarSensorTests {

    private let status = ThermalStatus(
        fans: [],
        temperatures: ["TC0P": 61, "Tp01": 58, "TG0P": 66, "Tg05": 70, "TH0x": 42, "TR0P": 50, "TA0P": 30]
    )

    @Test("CPU+GPU peak is the hottest CPU or GPU sensor")
    func cpuGPUPeak() {
        #expect(status.peakTemperature(prefixes: MenuBarSensor.cpuGPU.prefixes) == 70)
    }

    @Test("CPU ignores GPU sensors")
    func cpuOnly() {
        #expect(status.peakTemperature(prefixes: MenuBarSensor.cpu.prefixes) == 61)
    }

    @Test("GPU ignores CPU sensors")
    func gpuOnly() {
        #expect(status.peakTemperature(prefixes: MenuBarSensor.gpu.prefixes) == 70)
    }

    @Test("SSD reads only TH sensors")
    func ssdOnly() {
        #expect(status.peakTemperature(prefixes: MenuBarSensor.ssd.prefixes) == 42)
    }

    @Test("No matching sensor yields nil, not zero")
    func noMatch() {
        let empty = ThermalStatus(fans: [], temperatures: ["TA0P": 30])
        #expect(empty.peakTemperature(prefixes: MenuBarSensor.ssd.prefixes) == nil)
    }

    @Test("Default sensor is the CPU+GPU peak (previous behaviour)")
    func defaultSensor() {
        #expect(MenuBarSensor(rawValue: "") == nil)
        #expect(MenuBarSensor.stored(nil) == .cpuGPU)
        #expect(MenuBarSensor.stored("bogus") == .cpuGPU)
    }

    @Test("Sensor round-trips through its stored raw value")
    func sensorRoundTrip() {
        for sensor in MenuBarSensor.allCases {
            #expect(MenuBarSensor.stored(sensor.rawValue) == sensor)
        }
    }

    @Test("Menu bar content defaults to icon + temperature (previous behaviour)")
    func defaultContent() {
        #expect(MenuBarContent.stored(nil) == .iconAndTemperature)
        #expect(MenuBarContent.stored("bogus") == .iconAndTemperature)
        for content in MenuBarContent.allCases {
            #expect(MenuBarContent.stored(content.rawValue) == content)
        }
    }

    @Test("Only icon-only hides the temperature")
    func showsTemperature() {
        #expect(!MenuBarContent.iconOnly.showsTemperature)
        #expect(MenuBarContent.iconAndTemperature.showsTemperature)
        #expect(MenuBarContent.temperatureOnly.showsTemperature)
    }
}
