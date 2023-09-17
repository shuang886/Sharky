//
//  Shark.swift
//  Sharky
//
//  Created by Steven Huang on 9/14/23.
//

import CoreFoundation
import Foundation
import AVFoundation

typealias Frequency = Measurement<UnitFrequency>

enum FrequencyBand: String, CaseIterable {
    case am
    case fm
    
    func localizedString() -> String {
        switch self {
        case .am:
            return String(localized: "AM")
        case .fm:
            return String(localized: "FM")
        }
    }
    
    var range: ClosedRange<Frequency> {
        switch self {
        case .am:
            return Measurement(value: 520, unit: UnitFrequency.kilohertz)...Measurement(value: 1710, unit: UnitFrequency.kilohertz)
        case .fm:
            return Measurement(value: 87.5, unit: UnitFrequency.megahertz)...Measurement(value: 108, unit: UnitFrequency.megahertz)
        }
    }
    
    var step: Frequency {
        switch self {
        case .am:
            return Measurement(value: 10, unit: UnitFrequency.kilohertz)
        case .fm:
            return Measurement(value: 200, unit: UnitFrequency.kilohertz)
        }
    }
    
    func next() -> Self {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return all[next == all.endIndex ? all.startIndex : next]
    }
    
    init(from frequency: Frequency) throws {
        switch frequency {
        case Self.am.range:
            self = .am
        case Self.fm.range:
            self = .fm
        default:
            throw "frequency out of range"
        }
    }
}

struct Station: Identifiable {
    let id = UUID()
    let frequency: Frequency
    var name: String = ""
}

struct SettingsOptions: OptionSet {
    let rawValue: UInt
    
    static var frequency      = SettingsOptions(rawValue: 1 << 0)
    static var volume         = SettingsOptions(rawValue: 1 << 1)
    static var blueLight      = SettingsOptions(rawValue: 1 << 2)
    static var blueLightPulse = SettingsOptions(rawValue: 1 << 3)
    static var redLight       = SettingsOptions(rawValue: 1 << 4)
    
    static var all            = SettingsOptions(rawValue: .max)
}

class Shark: ObservableObject {
    var isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    
    private var session: AVCaptureSession?
    private var output: AVCaptureAudioPreviewOutput?
    
    @Published var band: FrequencyBand {
        didSet {
            let newFrequency = frequencies[band]!
            if frequency != newFrequency {
                frequency = newFrequency
            }
        }
    }
    
    private var frequencies: [ FrequencyBand : Frequency ] = [:]
    @Published var frequency: Frequency {
        didSet {
            let newBand = try! FrequencyBand(from: frequency)
            if band != newBand {
                band = newBand
            }
            frequencies[band] = frequency
            applySettings(.frequency)
        }
    }
    
    @Published var volume: Double {
        didSet {
            if !isPreview {
                applySettings(.volume)
            }
        }
    }
    
    @Published var favorites: [Station] = []
    
    @Published var blueLight: Double {
        didSet {
            applySettings(.blueLight)
        }
    }
    
    @Published var blueLightPulse: Double {
        didSet {
            applySettings(.blueLightPulse)
        }
    }
    
    @Published var redLight: Double {
        didSet {
            applySettings(.redLight)
        }
    }
    
    init() {
        let defaults = UserDefaults.standard
        
        let band = {
            if let userValue = defaults.string(forKey: "band") {
                return FrequencyBand(rawValue: userValue) ?? .fm
            }
            return .fm
        }()
        
        let amFrequency = {
            let userValue = defaults.double(forKey: "amFrequency")
            let userFrequency = Measurement(value: userValue, unit: UnitFrequency.kilohertz)
            if FrequencyBand.am.range.contains(userFrequency) {
                return userFrequency
            }
            return Measurement(value: 1050, unit: UnitFrequency.kilohertz)
        }()
        
        let fmFrequency = {
            let userValue = defaults.double(forKey: "fmFrequency")
            let userFrequency = Measurement(value: userValue, unit: UnitFrequency.megahertz)
            if FrequencyBand.fm.range.contains(userFrequency) {
                return userFrequency
            }
            return Measurement(value: 88.5, unit: UnitFrequency.megahertz)
        }()
        
        self.band = band
        self.frequencies[.am] = amFrequency
        self.frequencies[.fm] = fmFrequency
        self.frequency = (band == .am) ? amFrequency : fmFrequency
        self.blueLight = defaults.double(forKey: "blueLight", default: 0)
        self.blueLightPulse = defaults.double(forKey: "blueLightPulse", default: 0)
        self.redLight = defaults.double(forKey: "redLight", default: 0)
        self.volume = defaults.double(forKey: "volume", default: 1)
        
        if !isPreview {
            self.session = AVCaptureSession()
            initAudioPlaythrough()
            if sharkOpen() < 0 {
                isPreview = true
            }
        }
        
        self.applySettings()
        
        // seems like one of the previous commands (tuning?) overrides the blue LED setting
        // so we force it off right afterwards
        self.applySettings(.blueLight)
    }
    
    deinit {
        if !isPreview {
            sharkClose()
        }
    }
    
    private func sendCommand(_ argv: [String]) {
        guard !isPreview else { return }
        
        #if DEBUG
        print("\(#function) \(argv)")
        #endif
        
        // insert argv[0]
        let fullArgs = [ "" ] + argv
        
        var cargs = fullArgs.map { strdup($0) }
        let _ = sharkCommand(Int32(cargs.count), &cargs)
        cargs.forEach { free($0) }
    }
    
    /// Connect the RadioSHARK to audio output
    private func initAudioPlaythrough() {
        guard !isPreview, let session else { return }
        
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified).devices
        guard let shark = devices.first(where: { $0.modelID.hasPrefix("RadioSHARK") || $0.modelID.hasPrefix("radioSHARK") }) else { return }
        
        do {
            try shark.lockForConfiguration()
            let input = try AVCaptureDeviceInput(device: shark)
            shark.unlockForConfiguration()
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            output = AVCaptureAudioPreviewOutput()
            if let output {
                output.volume = Float(volume)
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
            }
            
            session.startRunning()
        } catch {
            return
        }
    }
    
    private func applySettings(_ options: SettingsOptions = .all) {
        if !isPreview {
            var command: [String] = []
            
            if options.contains(.frequency) {
                switch band {
                case .am:
                    command += ["-a", String(Int(frequency.converted(to: .kilohertz).value))]
                case .fm:
                    command += ["-f", frequency.converted(to: .megahertz).value.formatted(.number.precision(.fractionLength(1)))]
                }
            }
            
            if options.contains(.blueLight) {
                command += ["-b", String(Int(blueLight))]
            }
            
            if options.contains(.blueLightPulse) {
                // blueLightPulse is 0 = off, 1 = slowest, 127 = fastest
                // device expects 0 = off, 1 = fastest, 127 = slowest
                var pulse = Int(blueLightPulse)
                if pulse > 0 {
                    pulse = 128 - pulse
                }
                command += ["-p", String(pulse)]
            }
            
            if options.contains(.redLight) {
                command += ["-r", String(Int(redLight))]
            }
            
            if !command.isEmpty {
                sendCommand(command)
            }
            
            if options.contains(.volume) {
                output?.volume = Float(volume)
            }
        }
    }

}

extension UserDefaults {
    func double(forKey key: String, default defaultValue: Double) -> Double {
        self.value(forKey: key) != nil ? double(forKey: key) : defaultValue
    }
}

extension String: Error {}
