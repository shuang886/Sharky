//
//  Shark.swift
//  Sharky
//
//  Created by Steven Huang on 9/14/23.
//

import CoreFoundation
import Foundation
import AVFoundation

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
    
    var range: ClosedRange<Measurement<UnitFrequency>> {
        switch self {
        case .am:
            return Measurement(value: 522, unit: UnitFrequency.kilohertz)...Measurement(value: 1710, unit: UnitFrequency.kilohertz)
        case .fm:
            return Measurement(value: 87.5, unit: UnitFrequency.megahertz)...Measurement(value: 108, unit: UnitFrequency.megahertz)
        }
    }
    
    var step: Measurement<UnitFrequency> {
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
}

class Shark: ObservableObject {
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    
    private var session: AVCaptureSession?
    private var output: AVCaptureAudioPreviewOutput?
    
    @Published var band: FrequencyBand {
        didSet {
            frequency = frequencies[band]!
        }
    }
    
    private var frequencies: [ FrequencyBand : Measurement<UnitFrequency> ] = [:]
    @Published var frequency: Measurement<UnitFrequency> {
        didSet {
            frequencies[band] = frequency
            applyFrequency()
        }
    }
    
    @Published var volume: Float = 1 {
        didSet {
            if !isPreview {
                output?.volume = volume
            }
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
        
        if !isPreview {
            self.session = AVCaptureSession()
            initAudioPlaythrough()
            sharkOpen()
        }
        
        applyFrequency()
    }
    
    deinit {
        if !isPreview {
            sharkClose()
        }
    }
    
    private func sendCommand(_ argv: [String]) {
        guard !isPreview else { return }
        
        print("\(#function) \(argv)")
        
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
                output.volume = volume
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
            }
            
            session.startRunning()
        } catch {
            return
        }
    }
    
    private func applyFrequency() {
        if !isPreview {
            switch band {
            case .am:
                sendCommand(["-a", frequency.converted(to: .kilohertz).value.formatted(.number.grouping(.never))])
            case .fm:
                sendCommand(["-f", frequency.converted(to: .megahertz).value.formatted(.number.precision(.fractionLength(1)))])
            }
        }
    }
}
