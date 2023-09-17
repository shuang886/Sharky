//
//  ContentView.swift
//  Sharky
//
//  Created by Steven Huang on 9/14/23.
//

import SwiftUI
import Sliders

private let sheen = Gradient(stops: [
    .init(color: .white.opacity(0.5), location: 0),
    .init(color: .white.opacity(0.1), location: 0.1),
    .init(color: .clear, location: 0.2),
])

struct ContentView: View {
    private let buttonWidth: CGFloat = 40
    private let scrubberHeight: CGFloat = 50
    private let scrubberWidth: CGFloat = 8
    
    @StateObject var shark = Shark()
    @State private var showingFavorites = false
    @State private var showingLights = false
    
    var body: some View {
        VStack(spacing: 0) {
            Label {
                Text("**radio**SHARK")
            } icon: {
                Image(systemName: "dot.radiowaves.up.forward")
                    .foregroundColor(.accentColor)
            }
            .labelStyle(TrailingIconStyle())
            .font(.largeTitle)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(8)
            
            HStack {
                VStack {
                    Button {
                        if shark.frequency < shark.band.range.upperBound {
                            shark.frequency += shark.band.step
                        }
                    } label: {
                        Image(systemName: "arrowtriangle.up")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    
                    Button {
                        showingFavorites.toggle()
                    } label: {
                        Image(systemName: "list.star")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    .disabled(shark.favorites.isEmpty)
                    .popover(isPresented: $showingFavorites, arrowEdge: .leading) {
                        List(shark.favorites) { item in
                            HStack {
                                let itemFrequency: String = {
                                    let band = try! FrequencyBand(from: item.frequency)
                                    switch band {
                                    case .am:
                                        return item.frequency.converted(to: .kilohertz).formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.grouping(.never)))
                                    case .fm:
                                        return item.frequency.converted(to: .megahertz).formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1))))
                                    }
                                }()
                                
                                Text(itemFrequency)
                                    .font(.title2)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                shark.frequency = item.frequency
                                showingFavorites = false
                            }
                        }
                    }
                    
                    Button {
                        if shark.frequency > shark.band.range.lowerBound {
                            shark.frequency -= shark.band.step
                        }
                    } label: {
                        Image(systemName: "arrowtriangle.down")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                }
                
                VStack {
                    ZStack {
                        if shark.isPreview {
                            Text("Preview Mode")
                                .padding(.horizontal, 5)
                                .foregroundColor(Color(NSColor.controlBackgroundColor))
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.orange.gradient)
                                )
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                        
                        VStack {
                            Spacer()
                            
                            let tick = { () -> (major: Double, minor: Double, label: Double, labelUnit: Double) in
                                switch shark.band {
                                case .am:
                                    return (Frequency(value: 100, unit: .kilohertz).converted(to: .hertz).value,
                                            Frequency(value: 50, unit: .kilohertz).converted(to: .hertz).value,
                                            Frequency(value: 100, unit: .kilohertz).converted(to: .hertz).value,
                                            Frequency(value: 1, unit: .kilohertz).converted(to: .hertz).value)
                                case .fm:
                                    return (Frequency(value: 1, unit: .megahertz).converted(to: .hertz).value,
                                            Frequency(value: 500, unit: .kilohertz).converted(to: .hertz).value,
                                            Frequency(value: 2, unit: .megahertz).converted(to: .hertz).value,
                                            Frequency(value: 1, unit: .megahertz).converted(to: .hertz).value)
                                }
                            }()
                            
                            RulerView(range: shark.band.range.values(in: .hertz),
                                      majorTick: tick.major,
                                      minorTick: tick.minor,
                                      labelTick: tick.label,
                                      labelUnit: tick.labelUnit)
                                .frame(height: scrubberHeight / 2)
                                .padding(.horizontal, scrubberWidth / 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .foregroundColor(Color(NSColor.controlBackgroundColor)))
                        }
                        
                        ValueSlider(value: .double(from: $shark.frequency),
                                    in: shark.band.range.values(in: .hertz),
                                    step: shark.band.step.converted(to: .hertz).value)
                            .valueSliderStyle(
                                HorizontalValueSliderStyle(
                                    track:
                                        RoundedRectangle(cornerRadius: 3)
                                            .frame(height: 2)
                                            .foregroundColor(Color(NSColor.controlBackgroundColor)),
                                    thumb:
                                        Capsule()
                                            .foregroundColor(.init(white: 0.6))
                                            .overlay {
                                                Capsule()
                                                    .fill(sheen)
                                                    .padding(.horizontal, 1)
                                                    .padding(.vertical, 1)
                                                    .allowsHitTesting(false)
                                            },
                                    thumbSize: CGSize(width: scrubberWidth, height: 30)
                                )
                            )
                    }
                    .frame(height: scrubberHeight)

                    VStack {
                        HStack {
                            Text(shark.band.localizedString())
                                .font(.largeTitle)
                                .foregroundColor(.accentColor)
                                .shadow(color: .accentColor, radius: 3)
                            
                            Spacer()
                            
                            let frequencyString: String = {
                                switch shark.band {
                                case .am:
                                    return shark.frequency.converted(to: .kilohertz).formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.grouping(.never)))
                                case .fm:
                                    return shark.frequency.converted(to: .megahertz).formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1))))
                                }
                            }()
                            Text(frequencyString)
                                .font(.system(size: 60, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                                .shadow(color: .accentColor, radius: 4)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.black))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                Gradient(stops: [
                                    .init(color: .white.opacity(0.3), location: 0),
                                    .init(color: .white.opacity(0.1), location: 0.03),
                                    .init(color: .clear, location: 0.2),
                                    .init(color: .white.opacity(0.1), location: 1),
                                ])
                            )
                            .padding(.horizontal, 1)
                            .padding(.vertical, 2)
                            .allowsHitTesting(false)
                    )
                }
                
                VStack {
                    Spacer(minLength: scrubberHeight)
                    
                    ValueSlider(value: $shark.volume, in: 0...1)
                        .valueSliderStyle(
                            VerticalValueSliderStyle(
                                thumb:
                                    Circle()
                                        .foregroundColor(.init(white: 0.6))
                                        .overlay {
                                            Circle()
                                                .fill(sheen)
                                                .padding(.horizontal, 1)
                                                .padding(.vertical, 1)
                                                .allowsHitTesting(false)
                                        },
                                thumbSize: CGSize(width: 20, height: 20)
                            )
                        )
                        .frame(width: 30)
                        .padding(.vertical, 4)
                    
                    Image(systemName: "speaker.wave.3")
                        .foregroundColor(Color(NSColor.controlColor))
                }
                
                VStack {
                    let isFavorite = shark.favorites.contains(where: { $0.frequency == shark.frequency })
                    Button {
                        if !isFavorite {
                            shark.favorites.append(Station(frequency: shark.frequency))
                        }
                        else {
                            shark.favorites.removeAll(where: { $0.frequency == shark.frequency })
                        }
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    
                    Button {
                        shark.band = shark.band.next()
                    } label: {
                        Text(shark.band.next().localizedString())
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    
                    Button {
                        showingLights.toggle()
                    } label: {
                        Image(systemName: "light.max")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    .popover(isPresented: $showingLights, arrowEdge: .trailing) {
                        LightSettingsView(blueLight: $shark.blueLight, redLight: $shark.redLight)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .ignoresSafeArea()
        .background(
            Gradient(stops: [.init(color: Color(NSColor.underPageBackgroundColor), location: 0),
                             .init(color: Color(NSColor.windowBackgroundColor), location: 0.2)])
        )
    }
}

struct LightSettingsView: View {
    @Binding var blueLight: Double
    @Binding var redLight: Double
    
    var body: some View {
        VStack {
            Text("Blue Light")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Slider(value: $blueLight,
                   in: 0...127,
                   minimumValueLabel: Image(systemName: "light.min"),
                   maximumValueLabel: Image(systemName: "light.max"),
                   label: {})
                .tint(blueLight > 0 ? .blue : Color(NSColor.controlColor))
            
            Divider()
            
            Text("Red Light")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Slider(value: $redLight,
                   in: 0...127,
                   minimumValueLabel: Image(systemName: "light.min"),
                   maximumValueLabel: Image(systemName: "light.max"),
                   label: {})
                .tint(redLight > 0 ? .red : Color(NSColor.controlColor))
        }
        .padding(8)
        .frame(minWidth: 200)
    }
}

struct TrailingIconStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            configuration.title
            configuration.icon
        }
    }
}

struct SharkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    func makeBody(configuration: SharkButtonStyle.Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundColor(isEnabled ? Color(NSColor.controlTextColor) : Color(NSColor.disabledControlTextColor))
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(NSColor.controlColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(sheen)
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
                    .allowsHitTesting(false)
            )
            .compositingGroup()
            .shadow(color: .black, radius: 3, x: 2, y: 2)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

extension Binding {
    /// Converts a Binding<Measurement> to a Binding<Double> for SwiftUI elements
    static func double(from measurementBinding: Binding<Frequency>) -> Binding<Double> {
        Binding<Double> (
            get: { measurementBinding.wrappedValue.converted(to: UnitFrequency.hertz).value },
            set: { measurementBinding.wrappedValue = Measurement(value: Double($0), unit: UnitFrequency.hertz) }
        )
    }
}

extension Measurement where UnitType : Dimension {
    static func += (lhs: inout Measurement, rhs: Measurement) {
        lhs = lhs + rhs.converted(to: lhs.unit)
    }
    
    static func -= (lhs: inout Measurement, rhs: Measurement) {
        lhs = lhs - rhs.converted(to: lhs.unit)
    }
}

extension ClosedRange<Frequency> {
    func values(in otherUnit: UnitFrequency) -> ClosedRange<Double> {
        self.lowerBound.converted(to: otherUnit).value...self.upperBound.converted(to: otherUnit).value
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct LightSettingsView_Previews: PreviewProvider {
    @State static var blueLight: Double = 50
    @State static var redLight: Double = 100
    
    static var previews: some View {
        LightSettingsView(blueLight: $blueLight, redLight: $redLight)
            .frame(width: 200)
    }
}
