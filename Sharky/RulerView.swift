//
//  RulerView.swift
//  Sharky
//
//  Created by Steven Huang on 9/16/23.
//

import SwiftUI

struct RulerView: View {
    
    let range: ClosedRange<Double>
    let majorTick: Double
    let minorTick: Double
    var labelTick: Double?
    var labelUnit: Double?
    
    var body: some View {
        Canvas { context, size in
            let captionFont = NSFont.preferredFont(forTextStyle: .caption1)
            let labelHeight = captionFont.boundingRectForFont.height
            let majorHeight = size.height - labelHeight
            let minorHeight = majorHeight / 2
            
            let span = range.upperBound - range.lowerBound
            var path = Path()
            var value = range.lowerBound - range.lowerBound.truncatingRemainder(dividingBy: minorTick)
            while value < range.upperBound {
                let x = (value - range.lowerBound) / span * size.width
                
                // add a major tick or a minor tick
                path.move(to: CGPoint(x: x, y: 0))
                if value.truncatingRemainder(dividingBy: majorTick) < 1 {
                    path.addLine(to: CGPoint(x: x, y: majorHeight))
                }
                else {
                    path.addLine(to: CGPoint(x: x, y: minorHeight))
                }
                
                // add a label
                if value.truncatingRemainder(dividingBy: labelTick ?? majorTick) < 1 {
                    let label = (value / (labelUnit ?? majorTick)).formatted(.number.grouping(.never))
                    context.draw(Text(label).font(.caption), at: CGPoint(x: x, y: size.height), anchor: .bottom)
                }
                
                value += minorTick
            }
            context.stroke(path, with: .foreground, lineWidth: 1)
        }
    }
}

struct RulerView_Previews: PreviewProvider {
    static var previews: some View {
        RulerView(range: 87_500_000.0...93_000_000.0, majorTick: 1_000_000.0, minorTick: 100_000)
            .frame(width: 500, height: 50)
    }
}
