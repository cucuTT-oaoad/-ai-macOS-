import SpriteKit
import CoreGraphics
import AppKit

func makeTexture(size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
    let w = max(1, Int(size.width)), h = max(1, Int(size.height))
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: w, height: h,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
    draw(ctx)
    let img = ctx.makeImage()!
    return SKTexture(cgImage: img)
}

enum Art {

    static let player = makeTexture(size: CGSize(width: 64, height: 64)) { c in
        c.setFillColor(NSColor.darkGray.cgColor)
        c.fill(CGRect(x: 30, y: 30, width: 30, height: 6))
        c.setFillColor(NSColor(red: 0.35, green: 0.62, blue: 0.30, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 18, y: 18, width: 28, height: 28))
        c.setStrokeColor(NSColor(red: 0.20, green: 0.40, blue: 0.18, alpha: 1).cgColor)
        c.setLineWidth(3)
        c.strokeEllipse(in: CGRect(x: 18, y: 18, width: 28, height: 28))
        c.setFillColor(NSColor(red: 0.25, green: 0.45, blue: 0.22, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 24, y: 24, width: 16, height: 16))
    }

    static let enemyGrunt = makeTexture(size: CGSize(width: 48, height: 48)) { c in
        c.setFillColor(NSColor(red: 0.85, green: 0.22, blue: 0.18, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 6, y: 6, width: 36, height: 36))
        c.setFillColor(NSColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 18, y: 26, width: 5, height: 5))
        c.fillEllipse(in: CGRect(x: 26, y: 26, width: 5, height: 5))
    }

    static let enemyRunner = makeTexture(size: CGSize(width: 40, height: 40)) { c in
        c.setFillColor(NSColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 5, y: 5, width: 30, height: 30))
        c.setFillColor(NSColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 14, y: 21, width: 4, height: 4))
        c.fillEllipse(in: CGRect(x: 21, y: 21, width: 4, height: 4))
    }

    static let enemyShooter = makeTexture(size: CGSize(width: 48, height: 48)) { c in
        c.setFillColor(NSColor(red: 0.55, green: 0.30, blue: 0.80, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 6, y: 6, width: 36, height: 36))
        c.setFillColor(NSColor.darkGray.cgColor)
        c.fill(CGRect(x: 30, y: 21, width: 16, height: 5))
        c.setFillColor(NSColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 16, y: 26, width: 5, height: 5))
    }

    static let bulletP = makeTexture(size: CGSize(width: 14, height: 8)) { c in
        c.setFillColor(NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 0, y: 1, width: 14, height: 6))
    }

    static let bulletE = makeTexture(size: CGSize(width: 12, height: 6)) { c in
        c.setFillColor(NSColor(red: 1, green: 0.3, blue: 0.2, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 0, y: 1, width: 12, height: 4))
    }

    static let grass = makeTexture(size: CGSize(width: 96, height: 96)) { c in
        let colors: [CGColor] = [
            NSColor(red: 0.35, green: 0.55, blue: 0.25, alpha: 0.8).cgColor,
            NSColor(red: 0.42, green: 0.62, blue: 0.30, alpha: 0.8).cgColor,
            NSColor(red: 0.28, green: 0.48, blue: 0.22, alpha: 0.8).cgColor
        ]
        var rng = SoundManager.LCG(seed: 7)
        for i in 0..<7 {
            let x = CGFloat(rng.noise()) * 24 + 48
            let y = CGFloat(rng.noise()) * 24 + 48
            let r = CGFloat(12 + Int(rng.noise() * 10))
            c.setFillColor(colors[i % 3])
            c.fillEllipse(in: CGRect(x: x - r/2, y: y - r/2, width: r, height: r * 0.6))
        }
    }

    static let tree = makeTexture(size: CGSize(width: 72, height: 72)) { c in
        c.setFillColor(NSColor.black.withAlphaComponent(0.25).cgColor)
        c.fillEllipse(in: CGRect(x: 14, y: 10, width: 48, height: 20))
        c.setFillColor(NSColor(red: 0.18, green: 0.38, blue: 0.20, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 8, y: 14, width: 56, height: 52))
        c.setFillColor(NSColor(red: 0.28, green: 0.50, blue: 0.26, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 18, y: 26, width: 32, height: 28))
    }

    static let sandbagH = makeTexture(size: CGSize(width: 110, height: 30)) { c in
        c.setFillColor(NSColor(red: 0.72, green: 0.62, blue: 0.42, alpha: 1).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 110, height: 30))
        c.setStrokeColor(NSColor(red: 0.45, green: 0.36, blue: 0.22, alpha: 1).cgColor)
        c.setLineWidth(2)
        c.stroke(CGRect(x: 1, y: 1, width: 108, height: 28))
        for i in 1...3 {
            c.move(to: CGPoint(x: CGFloat(i * 27), y: 2))
            c.addLine(to: CGPoint(x: CGFloat(i * 27), y: 28))
            c.strokePath()
        }
    }

    static let sandbagV = makeTexture(size: CGSize(width: 30, height: 110)) { c in
        c.setFillColor(NSColor(red: 0.72, green: 0.62, blue: 0.42, alpha: 1).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 30, height: 110))
        c.setStrokeColor(NSColor(red: 0.45, green: 0.36, blue: 0.22, alpha: 1).cgColor)
        c.setLineWidth(2)
        c.stroke(CGRect(x: 1, y: 1, width: 28, height: 108))
        for i in 1...3 {
            c.move(to: CGPoint(x: 2, y: CGFloat(i * 27)))
            c.addLine(to: CGPoint(x: 28, y: CGFloat(i * 27)))
            c.strokePath()
        }
    }

    static let crate = makeTexture(size: CGSize(width: 48, height: 48)) { c in
        c.setFillColor(NSColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 48, height: 48))
        c.setStrokeColor(NSColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1).cgColor)
        c.setLineWidth(3)
        c.stroke(CGRect(x: 2, y: 2, width: 44, height: 44))
        c.move(to: CGPoint(x: 4, y: 4)); c.addLine(to: CGPoint(x: 44, y: 44))
        c.move(to: CGPoint(x: 44, y: 4)); c.addLine(to: CGPoint(x: 4, y: 44))
        c.strokePath()
    }

    static let weaponCrate = makeTexture(size: CGSize(width: 40, height: 40)) { c in
        c.setFillColor(NSColor(red: 0.40, green: 0.48, blue: 0.30, alpha: 1).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        c.setStrokeColor(NSColor.white.cgColor)
        c.setLineWidth(2)
        c.stroke(CGRect(x: 3, y: 3, width: 34, height: 34))
        c.setFillColor(NSColor.white.cgColor)
        c.fill(CGRect(x: 18, y: 10, width: 4, height: 20))
        c.fill(CGRect(x: 10, y: 18, width: 20, height: 4))
    }

    static let ammoBox = makeTexture(size: CGSize(width: 26, height: 26)) { c in
        c.setFillColor(NSColor(red: 0.50, green: 0.52, blue: 0.55, alpha: 1).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 26, height: 26))
        c.setStrokeColor(NSColor.black.cgColor)
        c.setLineWidth(1.5)
        c.stroke(CGRect(x: 1, y: 1, width: 24, height: 24))
    }

    static let medkit = makeTexture(size: CGSize(width: 30, height: 30)) { c in
        c.setFillColor(NSColor.white.cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
        c.setFillColor(NSColor.red.cgColor)
        c.fill(CGRect(x: 13, y: 7, width: 4, height: 16))
        c.fill(CGRect(x: 7, y: 13, width: 16, height: 4))
    }

    static let flash = makeTexture(size: CGSize(width: 40, height: 40)) { c in
        c.setFillColor(NSColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.9).cgColor)
        c.fillEllipse(in: CGRect(x: 8, y: 8, width: 24, height: 24))
        c.setFillColor(NSColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 14, y: 14, width: 12, height: 12))
    }

    static let crosshair = makeTexture(size: CGSize(width: 28, height: 28)) { c in
        c.setStrokeColor(NSColor.white.cgColor)
        c.setLineWidth(1.5)
        c.strokeEllipse(in: CGRect(x: 8, y: 8, width: 12, height: 12))
        c.stroke(CGRect(x: 13, y: 2, width: 2, height: 6))
        c.stroke(CGRect(x: 13, y: 20, width: 2, height: 6))
        c.stroke(CGRect(x: 2, y: 13, width: 6, height: 2))
        c.stroke(CGRect(x: 20, y: 13, width: 6, height: 2))
    }

    static let blood = makeTexture(size: CGSize(width: 10, height: 10)) { c in
        c.setFillColor(NSColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    static let spark = makeTexture(size: CGSize(width: 12, height: 12)) { c in
        c.setFillColor(NSColor(red: 1, green: 0.9, blue: 0.3, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: 1, y: 1, width: 10, height: 10))
    }

    private static var groundCache: [Int: SKTexture] = [:]
    static func groundTexture(_ idx: Int) -> SKTexture {
        if let t = groundCache[idx] { return t }
        let bases: [(CGFloat, CGFloat, CGFloat)] = [
            (0.42, 0.58, 0.30), (0.46, 0.62, 0.33), (0.38, 0.54, 0.28),
            (0.52, 0.54, 0.32), (0.44, 0.58, 0.36)
        ]
        let b = bases[idx % bases.count]
        let t = makeTexture(size: CGSize(width: 256, height: 256)) { c in
            c.setFillColor(NSColor(red: b.0, green: b.1, blue: b.2, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            var rng = SoundManager.LCG(seed: UInt64(idx &* 2654435761 &+ 1))
            for _ in 0..<160 {
                let x = CGFloat(rng.noise()) * 128 + 128
                let y = CGFloat(rng.noise()) * 128 + 128
                let s = CGFloat(2 + Int(rng.noise() * 3))
                let shade = 0.06 * CGFloat(rng.noise())
                c.setFillColor(NSColor(red: b.0 - shade, green: b.1 - shade,
                                       blue: b.2 - shade, alpha: 1).cgColor)
                c.fill(CGRect(x: x, y: y, width: s, height: s))
            }
        }
        groundCache[idx] = t
        return t
    }

    private static var buildingCache: [Int: SKTexture] = [:]
    static func buildingTexture(w: CGFloat, h: CGFloat) -> SKTexture {
        let key = Int(w * 1000) &* 73856093 &+ Int(h * 1000)
        if let t = buildingCache[key] { return t }
        let t = makeTexture(size: CGSize(width: w, height: h)) { c in
            c.setFillColor(NSColor(red: 0.36, green: 0.37, blue: 0.40, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            c.setStrokeColor(NSColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1).cgColor)
            c.setLineWidth(6)
            c.stroke(CGRect(x: 0, y: 0, width: w, height: h))
            c.setStrokeColor(NSColor(red: 0.45, green: 0.46, blue: 0.49, alpha: 1).cgColor)
            c.setLineWidth(2)
            for i in 1..<4 {
                let yy = h * CGFloat(i) / 4
                c.move(to: CGPoint(x: 6, y: yy)); c.addLine(to: CGPoint(x: w - 6, y: yy)); c.strokePath()
            }
            c.setFillColor(NSColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1).cgColor)
            c.fill(CGRect(x: w * 0.6, y: h * 0.6, width: 40, height: 28))
        }
        buildingCache[key] = t
        return t
    }
}
