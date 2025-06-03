import SwiftUI
import Foundation

/// A gauge icon for the menu bar that displays spending as a percentage of the limit.
/// Use between 0‒1
struct GaugeIcon: View {
    var value: Double
    
    private let lineRatio   = 0.18          // stroke thickness vs. frame
    private let startAngle  = 210.0         // ° (left-down)
    private let sweepAngle  = -240.0        // clockwise span
    
    var body: some View {
        Canvas { ctx, size in
            let line      = size.width * lineRatio
            let radius    = size.width / 2 - line / 2
            let center    = CGPoint(x: size.width / 2, y: size.height / 2)
            let endAngle  = startAngle + sweepAngle * value
            let trackPath = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(startAngle),
                         endAngle:   .degrees(startAngle + sweepAngle),
                         clockwise:  true)
            }
            let progPath  = Path { p in
                p.addArc(center: center,
                         radius: radius,
                         startAngle: .degrees(startAngle),
                         endAngle:   .degrees(endAngle),
                         clockwise:  true)
            }
            
            // track
            ctx.stroke(trackPath,
                       with: .color(.white.opacity(0.25)),
                       style: StrokeStyle(lineWidth: line, lineCap: .round))
            
            // coloured arc
            ctx.stroke(progPath,
                       with: .color(color(for: value)),
                       style: StrokeStyle(lineWidth: line, lineCap: .round))
            
            // optional needle
            let needleLen = radius * 0.82
            let rad = Double(endAngle) * .pi / 180
            let tip = CGPoint(x: center.x + needleLen * CGFloat(Foundation.cos(rad)),
                              y: center.y + needleLen * CGFloat(Foundation.sin(rad)))
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: tip)
            ctx.stroke(needle,
                       with: .color(.white),
                       style: StrokeStyle(lineWidth: line * 0.5, lineCap: .round))
        }
        .frame(width: 22, height: 22)       // menu-bar size (@1×; doubles on Retina)
    }
    
    /// Rainbow-ish gradient from teal→green→yellow→orange→red
    private func color(for v: Double) -> Color {
        let palette: [Color] = [.teal, .green, .yellow, .orange, .red]
        let seg = min(4, Int(v * 4))
        let t   = v * 4 - Double(seg)
        return palette[seg].blend(with: palette[min(seg + 1, 4)], ratio: t)
    }
}

/// Handy blending helper
private extension Color {
    func blend(with other: Color, ratio: Double) -> Color {
        let nsColor1 = NSColor(self).usingColorSpace(.deviceRGB)!
        let r1 = nsColor1.redComponent
        let g1 = nsColor1.greenComponent
        let b1 = nsColor1.blueComponent
        
        let nsColor2 = NSColor(other).usingColorSpace(.deviceRGB)!
        let r2 = nsColor2.redComponent
        let g2 = nsColor2.greenComponent
        let b2 = nsColor2.blueComponent
        
        return Color(red: r1 + (r2 - r1) * ratio,
                     green: g1 + (g2 - g1) * ratio,
                     blue: b1 + (b2 - b1) * ratio)
    }
}

// MARK: - Preview

#Preview("Gauge Icon - Various Values") {
    VStack(spacing: 20) {
        HStack(spacing: 30) {
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                VStack {
                    GaugeIcon(value: value)
                        .scaleEffect(2) // Make it easier to see in preview
                    Text("\(Int(value * 100))%")
                        .font(.caption)
                }
            }
        }
        
        // Animated preview
        TimelineView(.animation) { timeline in
            let progress = (sin(timeline.date.timeIntervalSinceReferenceDate) + 1) / 2
            VStack {
                GaugeIcon(value: progress)
                    .scaleEffect(4)
                Text("\(Int(progress * 100))%")
                    .font(.title3)
            }
        }
    }
    .padding()
    .frame(width: 400, height: 300)
}