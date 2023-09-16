//
//  Shark.swift
//  Sharky
//
//  Created by Steven Huang on 9/14/23.
//

import CoreFoundation
import Foundation
import AVFoundation

class Shark: ObservableObject {
    let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    
    var session: AVCaptureSession?
    var output: AVCaptureAudioPreviewOutput?
    
    let bandMinimum = Measurement(value: 88.1, unit: UnitFrequency.megahertz)
    let bandMaximum = Measurement(value: 107.9, unit: UnitFrequency.megahertz)
    let bandStep = Measurement(value: 200, unit: UnitFrequency.kilohertz)
    @Published var frequency: Measurement<UnitFrequency> {
        didSet {
            if !isPreview {
                sendCommand(["-f", frequency.converted(to: .megahertz).value.formatted(.number.precision(.fractionLength(1)))])
            }
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
        self.frequency = Measurement(value: 88.5, unit: UnitFrequency.megahertz)
        
        if !isPreview {
            self.session = AVCaptureSession()
            initAudioPlaythrough()
            sharkOpen()
        }
    }
    
    deinit {
        if !isPreview {
            sharkClose()
        }
    }
    
    func sendCommand(_ argv: [String]) {
        guard !isPreview else { return }
        
        // insert argv[0]
        let fullArgs = [ "" ] + argv
        
        var cargs = fullArgs.map { strdup($0) }
        let _ = sharkCommand(Int32(cargs.count), &cargs)
        cargs.forEach { free($0) }
    }
    
    /// Connect the RadioSHARK to audio output
    func initAudioPlaythrough() {
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
}
