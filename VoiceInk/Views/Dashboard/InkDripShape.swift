import SwiftUI

/// A band of ink along the top edge with drips running down from it, in the
/// flat-vector style of a poured-ink illustration: solid black, hard edges,
/// no gradients, no texture, no motion.
///
/// The drip run is fixed rather than random so the card looks the same every
/// time it opens. Positions are proportions of the width, so the pour stays
/// balanced at any card size.
struct InkDripShape: Shape {
    /// Height of the solid band the drips hang from, in points.
    var bandHeight: CGFloat = 5

    /// Each drip: horizontal position as a fraction of width, how far the bead
    /// hangs below the band, and the bead's radius. The neck is sized from the
    /// bead so a heavy drop always has a correspondingly thick run.
    private struct Drip {
        let position: CGFloat
        let length: CGFloat
        let bead: CGFloat
    }

    /// Hand-placed so the spacing reads as uneven the way a real pour does:
    /// one long run left of center, shorter runs spread unevenly around it.
    /// Kept sparse on purpose. The mark should read as a detail on the card,
    /// not as the subject of it.
    private static let drips: [Drip] = [
        Drip(position: 0.08, length: 11, bead: 3.5),
        Drip(position: 0.23, length: 24, bead: 4),
        Drip(position: 0.37, length: 8, bead: 3),
        Drip(position: 0.52, length: 34, bead: 4.5),
        Drip(position: 0.71, length: 15, bead: 3.5),
        Drip(position: 0.88, length: 20, bead: 4),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let bandBottom = rect.minY + bandHeight
        // The band thins to nothing at both ends, so the ink reads as a pour
        // that ran across the card rather than a header bar ruled onto it.
        let taper = min(rect.width * 0.12, 90)
        var band = Path()
        band.move(to: CGPoint(x: rect.minX, y: rect.minY))
        band.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        band.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bandHeight * 0.18))
        band.addQuadCurve(
            to: CGPoint(x: rect.maxX - taper, y: bandBottom),
            control: CGPoint(x: rect.maxX - taper * 0.45, y: bandBottom)
        )
        band.addLine(to: CGPoint(x: rect.minX + taper, y: bandBottom))
        band.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + bandHeight * 0.18),
            control: CGPoint(x: rect.minX + taper * 0.45, y: bandBottom)
        )
        band.closeSubpath()
        path.addPath(band)

        for drip in Self.drips {
            let centerX = rect.minX + rect.width * drip.position
            let beadCenterY = bandBottom + drip.length
            // The neck is nearly as wide as the bead, as in a poured-ink
            // illustration, and flares wider still where it meets the band.
            let halfNeck = drip.bead * 0.66
            let halfShoulder = drip.bead * 1.05
            // How far down the shoulder fillet blends into the straight run.
            let shoulderDrop = min(drip.bead * 1.2, drip.length * 0.4)

            var body = Path()
            body.move(to: CGPoint(x: centerX - halfShoulder, y: bandBottom))
            // Shoulder: the ink pulls away from the band in a smooth fillet
            // rather than starting at full neck width.
            body.addQuadCurve(
                to: CGPoint(x: centerX - halfNeck, y: bandBottom + shoulderDrop),
                control: CGPoint(x: centerX - halfNeck, y: bandBottom + shoulderDrop * 0.35)
            )
            // Run down into the bead, swelling slightly as it goes.
            body.addCurve(
                to: CGPoint(x: centerX - drip.bead, y: beadCenterY),
                control1: CGPoint(x: centerX - halfNeck, y: beadCenterY - drip.bead * 1.5),
                control2: CGPoint(x: centerX - drip.bead, y: beadCenterY - drip.bead * 0.9)
            )
            body.addArc(
                center: CGPoint(x: centerX, y: beadCenterY),
                radius: drip.bead,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: true
            )
            body.addCurve(
                to: CGPoint(x: centerX + halfNeck, y: bandBottom + shoulderDrop),
                control1: CGPoint(x: centerX + drip.bead, y: beadCenterY - drip.bead * 0.9),
                control2: CGPoint(x: centerX + halfNeck, y: beadCenterY - drip.bead * 1.5)
            )
            body.addQuadCurve(
                to: CGPoint(x: centerX + halfShoulder, y: bandBottom),
                control: CGPoint(x: centerX + halfNeck, y: bandBottom + shoulderDrop * 0.35)
            )
            body.closeSubpath()

            path.addPath(body)
        }

        return path
    }
}

/// A single hanging drop, for places too small to read a whole pour.
struct InkDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let bead = min(rect.width, rect.height * 0.42) / 2
        let centerX = rect.midX
        let beadCenterY = rect.maxY - bead
        let halfNeck = bead * 0.42

        path.move(to: CGPoint(x: centerX - halfNeck, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: centerX - bead, y: beadCenterY),
            control1: CGPoint(x: centerX - halfNeck, y: beadCenterY - bead * 1.5),
            control2: CGPoint(x: centerX - bead, y: beadCenterY - bead * 0.9)
        )
        path.addArc(
            center: CGPoint(x: centerX, y: beadCenterY),
            radius: bead,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addCurve(
            to: CGPoint(x: centerX + halfNeck, y: rect.minY),
            control1: CGPoint(x: centerX + bead, y: beadCenterY - bead * 0.9),
            control2: CGPoint(x: centerX + halfNeck, y: beadCenterY - bead * 1.5)
        )
        path.closeSubpath()

        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        InkDripShape()
            .fill(Color.black)
            .frame(width: 640, height: 60)
        InkDropShape()
            .fill(Color.black)
            .frame(width: 14, height: 32)
    }
    .padding()
    .background(Color.white)
}
