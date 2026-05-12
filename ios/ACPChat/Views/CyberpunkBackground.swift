//
//  CyberpunkBackground.swift
//
//  Tech / cyberpunk wallpaper for the chat transcript. Layered:
//    1. dark vertical gradient (near-black → DS.bgSubtle)
//    2. radial glow in top-left (cyan) and bottom-right (magenta/indigo)
//    3. faint grid lattice via Canvas
//    4. slow-moving scan lines (horizontal, low alpha) — pure CoreAnimation-free
//       (SwiftUI TimelineView, battery-friendly ~12 fps)
//    5. soft vignette to keep message bubbles readable
//
//  Use as `.background(CyberpunkBackground().ignoresSafeArea())` on any view.
//

import SwiftUI

struct CyberpunkBackground: View {
    /// Whether to animate scan lines. Disabled when user turns off Low Power
    /// mode? Keep it simple — always on, 12 fps costs ~nothing.
    var animated: Bool = true

    var body: some View {
        ZStack {
            baseGradient
            glowLayer
            gridLayer
            if animated { scanLines }
            vignette
        }
        .drawingGroup(opaque: true) // rasterize for scroll perf
    }

    // MARK: - 1. Base gradient

    private var baseGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x05060A),   // near-black w/ blue hint
                Color(hex: 0x0B0F1C),   // deep navy
                Color(hex: 0x111827),   // DS.bgSubtle (dark)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - 2. Colour glow (corner radials)

    private var glowLayer: some View {
        ZStack {
            // Top-left cyan
            RadialGradient(
                colors: [DS.P.s500.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            // Bottom-right magenta
            RadialGradient(
                colors: [DS.P.a500.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 460
            )
            // Mid-left indigo streak (subtle)
            RadialGradient(
                colors: [DS.P.p500.opacity(0.18), .clear],
                center: UnitPoint(x: -0.1, y: 0.55),
                startRadius: 0,
                endRadius: 360
            )
        }
        .blendMode(.plusLighter)
    }

    // MARK: - 3. Grid lattice

    private var gridLayer: some View {
        Canvas { ctx, size in
            let step: CGFloat = 40
            let lineColor = DS.P.s500.opacity(0.09)
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            ctx.stroke(path, with: .color(lineColor), lineWidth: 0.5)

            // a few brighter "highlight" verticals for depth
            let bright = DS.P.s500.opacity(0.18)
            for i in 0..<3 {
                let hx = size.width * CGFloat([0.18, 0.56, 0.88][i])
                var hp = Path()
                hp.move(to: CGPoint(x: hx, y: 0))
                hp.addLine(to: CGPoint(x: hx, y: size.height))
                ctx.stroke(hp, with: .color(bright), lineWidth: 0.8)
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    // MARK: - 4. Scan lines

    private var scanLines: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gtx, size in
                // main scan: slow top→bottom sweep, repeats every 6s
                let period: CGFloat = 6
                let phase = CGFloat(t.truncatingRemainder(dividingBy: Double(period))) / period
                let y = phase * size.height
                let band: CGFloat = 90
                let rect = CGRect(x: 0, y: y - band / 2, width: size.width, height: band)
                let gradient = Gradient(colors: [
                    DS.P.s500.opacity(0.0),
                    DS.P.s500.opacity(0.10),
                    DS.P.s500.opacity(0.0),
                ])
                gtx.fill(
                    Path(rect),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: rect.minY),
                        endPoint: CGPoint(x: 0, y: rect.maxY)
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }

    // MARK: - 5. Vignette (edges darker for bubble readability)

    private var vignette: some View {
        RadialGradient(
            colors: [.clear, Color.black.opacity(0.45)],
            center: .center,
            startRadius: 180,
            endRadius: 600
        )
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview {
    CyberpunkBackground().ignoresSafeArea()
}
#endif
