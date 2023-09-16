//
//  ContentView.swift
//  Sharky
//
//  Created by Steven Huang on 9/14/23.
//

import SwiftUI

struct ContentView: View {
    @State var shark = Shark()
    
    private let buttonWidth: CGFloat = 40
    
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
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            Spacer()
            
            HStack {
                VStack {
                    Button {
                        if shark.frequency < shark.bandMaximum {
                            shark.frequency += shark.bandStep
                        }
                    } label: {
                        Image(systemName: "arrowtriangle.up")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "list.star")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    
                    Button {
                        if shark.frequency > shark.bandMinimum {
                            shark.frequency -= shark.bandStep
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
                    Slider(value: .double(from: $shark.frequency),
                           in: shark.bandMinimum.converted(to: .hertz).value...shark.bandMaximum.converted(to: .hertz).value,
                           step: shark.bandStep.converted(to: .hertz).value,
                           minimumValueLabel: Text("88"),
                           maximumValueLabel: Text("108"),
                           label: {})
                    .padding(8)
                    
                    VStack {
                        HStack {
                            Text("FM")
                                .font(.largeTitle)
                                .foregroundColor(.accentColor)
                                .shadow(color: .accentColor, radius: 3)
                            
                            Spacer()
                            
                            Text(shark.frequency.converted(to: .megahertz).formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1)))))
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
                    
                    Slider(value: $shark.volume,
                           in: 0...1,
                           minimumValueLabel: Image(systemName: "speaker"),
                           maximumValueLabel: Image(systemName: "speaker.wave.3"),
                           label: {})
                    .padding(8)
                }
                
                VStack {
                    Button {
                    } label: {
                        Image(systemName: "heart")
                            .imageScale(.large)
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
                    
                    Button {
                    } label: {
                        Text("FM")
                            .frame(idealWidth: buttonWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SharkButtonStyle())
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

struct TrailingIconStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            configuration.title
            configuration.icon
        }
    }
}

struct SharkButtonStyle: ButtonStyle {
    public func makeBody(configuration: SharkButtonStyle.Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundColor(Color(NSColor.controlTextColor))
            .background(RoundedRectangle(cornerRadius: 5)
                .fill(Color(NSColor.controlColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        Gradient(stops: [
                            .init(color: .white.opacity(0.5), location: 0),
                            .init(color: .white.opacity(0.1), location: 0.1),
                            .init(color: .clear, location: 0.2),
                        ])
                    )
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

public extension Binding {
    /// Converts a Binding<Measurement> to a Binding<Double> for SwiftUI elements
    static func double(from measurementBinding: Binding<Measurement<UnitFrequency>>) -> Binding<Double> {
        Binding<Double> (
            get: { measurementBinding.wrappedValue.converted(to: UnitFrequency.hertz).value },
            set: { measurementBinding.wrappedValue = Measurement(value: Double($0), unit: UnitFrequency.hertz) }
        )
    }
}

public extension Measurement where UnitType : Dimension {
    static func += (lhs: inout Measurement, rhs: Measurement) {
        lhs = lhs + rhs.converted(to: lhs.unit)
    }
    
    static func -= (lhs: inout Measurement, rhs: Measurement) {
        lhs = lhs - rhs.converted(to: lhs.unit)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
