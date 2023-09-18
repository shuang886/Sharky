//
//  Shark.swift
//  Sharky
//
//  Created by Steven Huang on 9/14/23.
//

import CoreFoundation
import Foundation
import AVFoundation
import Speech

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

struct Station: Identifiable, Codable {
    var id = UUID()
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

class Shark: NSObject, ObservableObject {
    private static let userDefaultsKeyBand = "band"
    private static let userDefaultsKeyAMFrequency = "amFrequency"
    private static let userDefaultsKeyFMFrequency = "fmFrequency"
    private static let userDefaultsKeyBlueLight = "blueLight"
    private static let userDefaultsKeyBlueLightPulse = "blueLightPulse"
    private static let userDefaultsKeyRedLight = "redLight"
    private static let userDefaultsKeyVolume = "volume"
    private static let userDefaultsKeyFavorites = "favorites"
    
    var isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    
    private var session: AVCaptureSession?
    private var playthroughOutput: AVCaptureAudioPreviewOutput?
    
    private var speechOutput: AVCaptureAudioDataOutput?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    @Published var isRecognizing = false
    @Published var recognizedText: String = ""
    
    @Published var band: FrequencyBand {
        didSet {
            // switch to the saved frequency if changing bands
            let newFrequency = frequencies[band]!
            if frequency != newFrequency {
                frequency = newFrequency
            }
            
            UserDefaults.standard.setValue(band.rawValue, forKey: Self.userDefaultsKeyBand)
        }
    }
    
    private var frequencies: [ FrequencyBand : Frequency ] = [:]
    @Published var frequency: Frequency {
        didSet {
            // selecting a favorite can cause a band switch
            let newBand = try! FrequencyBand(from: frequency)
            if band != newBand {
                band = newBand
            }
            
            frequencies[band] = frequency
            applySettings(.frequency)
            
            switch band {
            case .am:
                UserDefaults.standard.setValue(frequency.converted(to: .hertz).value, forKey: Self.userDefaultsKeyAMFrequency)
            case .fm:
                UserDefaults.standard.setValue(frequency.converted(to: .hertz).value, forKey: Self.userDefaultsKeyFMFrequency)
            }
        }
    }
    
    @Published var volume: Double {
        didSet {
            if !isPreview {
                applySettings(.volume)
            }
            UserDefaults.standard.setValue(volume, forKey: Self.userDefaultsKeyVolume)
        }
    }
    
    @Published var favorites: [Station] = [] {
        didSet {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(favorites) {
                UserDefaults.standard.setValue(encoded, forKey: Self.userDefaultsKeyFavorites)
            }
        }
    }
    
    @Published var blueLight: Double {
        didSet {
            applySettings(.blueLight)
            UserDefaults.standard.setValue(blueLight, forKey: Self.userDefaultsKeyBlueLight)
        }
    }
    
    @Published var blueLightPulse: Double {
        didSet {
            applySettings(.blueLightPulse)
            UserDefaults.standard.setValue(blueLightPulse, forKey: Self.userDefaultsKeyBlueLightPulse)
        }
    }
    
    @Published var redLight: Double {
        didSet {
            applySettings(.redLight)
            UserDefaults.standard.setValue(blueLight, forKey: Self.userDefaultsKeyRedLight)
        }
    }
    
    override init() {
        let defaults = UserDefaults.standard
        
        let band = {
            if let userValue = defaults.string(forKey: Self.userDefaultsKeyBand) {
                return FrequencyBand(rawValue: userValue) ?? .fm
            }
            return .fm
        }()
        
        let amFrequency = {
            let userValue = defaults.double(forKey: Self.userDefaultsKeyAMFrequency)
            let userFrequency = Measurement(value: userValue, unit: UnitFrequency.hertz)
            if FrequencyBand.am.range.contains(userFrequency) {
                return userFrequency
            }
            return Measurement(value: 1050, unit: UnitFrequency.kilohertz)
        }()
        
        let fmFrequency = {
            let userValue = defaults.double(forKey: Self.userDefaultsKeyFMFrequency)
            let userFrequency = Measurement(value: userValue, unit: UnitFrequency.hertz)
            if FrequencyBand.fm.range.contains(userFrequency) {
                return userFrequency
            }
            return Measurement(value: 88.5, unit: UnitFrequency.megahertz)
        }()
        
        self.band = band
        self.frequencies[.am] = amFrequency
        self.frequencies[.fm] = fmFrequency
        self.frequency = (band == .am) ? amFrequency : fmFrequency
        self.blueLight = defaults.double(forKey: Self.userDefaultsKeyBlueLight, default: 0)
        self.blueLightPulse = defaults.double(forKey: Self.userDefaultsKeyBlueLightPulse, default: 0)
        self.redLight = defaults.double(forKey: Self.userDefaultsKeyRedLight, default: 0)
        self.volume = defaults.double(forKey: Self.userDefaultsKeyVolume, default: 1)
        
        if let favoritesData = defaults.object(forKey: Self.userDefaultsKeyFavorites) as? Data {
            let decoder = JSONDecoder()
            if let favorites = try? decoder.decode([Station].self, from: favoritesData) {
                self.favorites = favorites
            }
        }
        
        super.init()
        
        if !isPreview {
            self.session = AVCaptureSession()
            initAudioPlaythrough()
            if sharkOpen() < 0 {
                isPreview = true
            }
        }
        
        self.applySettings()
        
        // seems like one of the previous commands (tuning?) overrides the LED settings
        // so we make sure to apply them again
        self.applySettings([.blueLight, .blueLightPulse, .redLight])
    }
    
    deinit {
        guard !isPreview, let session else { return }
        
        session.stopRunning()
        
        // turn off the lights
        sendCommand(["-b", "0", "-r", "0", "-p", "0"])
            
        sharkClose()
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
            
            playthroughOutput = AVCaptureAudioPreviewOutput()
            if let playthroughOutput {
                playthroughOutput.volume = Float(volume)
                if session.canAddOutput(playthroughOutput) {
                    session.addOutput(playthroughOutput)
                }
            }
            
            session.startRunning()
        } catch {
            return
        }
    }
    
    private func applySettings(_ options: SettingsOptions = .all) {
        guard !isPreview else { return }
        
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
            playthroughOutput?.volume = Float(volume)
        }
    }
    
    func toggleRecognizer() {
        if isRecognizing {
            endRecognizer()
        }
        else {
            startRecognizer()
        }
    }
    
    private func startRecognizer() {
        guard !isPreview, let session else { return }
        
        SFSpeechRecognizer.requestAuthorization { [self] status in
            switch status {
            case .authorized:
                if let recognizer = SFSpeechRecognizer(locale: Locale.current) {
                    speechRequest = SFSpeechAudioBufferRecognitionRequest()
                    recognizer.recognitionTask(with: speechRequest!, delegate: self)
                    
                    speechOutput = AVCaptureAudioDataOutput()
                    if let speechOutput,
                       session.canAddOutput(speechOutput) {
                        speechOutput.connection(with: .audio)
                        speechOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
                        session.addOutput(speechOutput)
                        DispatchQueue.main.async { [self] in
                            isRecognizing = true
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    private func endRecognizer() {
        guard !isPreview, let session, let speechRequest, let speechOutput else { return }
        
        speechRequest.endAudio()
        self.speechRequest = nil
        
        session.removeOutput(speechOutput)
        self.speechOutput = nil
    }
}

extension Shark: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        speechRequest?.appendAudioSampleBuffer(sampleBuffer)
    }
}

extension Shark: SFSpeechRecognitionTaskDelegate {
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        recognizedText = String(transcription.formattedString.suffix(128))
    }
    
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
#if DEBUG
        print(#function)
#endif
        isRecognizing = false
    }
    
    func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
#if DEBUG
        print(#function)
#endif
        isRecognizing = false
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
#if DEBUG
        print(#function)
#endif
        isRecognizing = false
    }
}

extension UserDefaults {
    func double(forKey key: String, default defaultValue: Double) -> Double {
        self.value(forKey: key) != nil ? double(forKey: key) : defaultValue
    }
}

extension String: Error {}
