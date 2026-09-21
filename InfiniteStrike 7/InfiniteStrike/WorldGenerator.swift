import Foundation
import CoreGraphics

struct ChunkKey: Hashable { let cx: Int, cy: Int }

struct Structure { let rect: CGRect; let kind: StructureKind }
enum StructureKind { case building, sandbag, crate, tree }

struct GrassPatch { let pos: CGPoint; let scale: CGFloat }

enum PickupKind { case weapon(WeaponID), ammo, medkit }
struct PickupSpawn { let pos: CGPoint; let kind: PickupKind }

struct ChunkLayout {
    let cx: Int
    let cy: Int
    let groundTexture: Int
    var structures: [Structure] = []
    var grass: [GrassPatch] = []
    var pickups: [PickupSpawn] = []
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum WorldGenerator {

    static func chunkSeed(_ seed: UInt64, _ cx: Int, _ cy: Int) -> UInt64 {
        var h = seed
        h ^= UInt64(bitPattern: Int64(cx)) &* 0x9E3779B97F4A7C15
        h ^= UInt64(bitPattern: Int64(cy)) &* 0x85EBCA77C2B2AE63
        return h &+ 0x9E3779B97F4A7C15
    }

    static func generate(seed: UInt64, cx: Int, cy: Int) -> ChunkLayout {
        var rng = SplitMix64(state: chunkSeed(seed, cx, cy))
        let originX = CGFloat(cx) * G.chunkSize
        let originY = CGFloat(cy) * G.chunkSize
        let inset: CGFloat = 90

        var layout = ChunkLayout(cx: cx, cy: cy,
                                 groundTexture: Int(Double(rng.next() >> 11) / 9007199254740992.0 * 5.0))
        let isSpawn = (cx == 0 && cy == 0)

        func rnd() -> Double { Double(rng.next() >> 11) / 9007199254740992.0 }
        func rndRange(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
            a + CGFloat(rnd()) * (b - a)
        }
        func interiorPoint(margin: CGFloat) -> CGPoint {
            CGPoint(x: originX + margin + CGFloat(rnd()) * (G.chunkSize - 2 * margin),
                    y: originY + margin + CGFloat(rnd()) * (G.chunkSize - 2 * margin))
        }
        func overlapsStructures(_ rect: CGRect) -> Bool {
            for s in layout.structures {
                if s.rect.insetBy(dx: -24, dy: -24).intersects(rect) { return true }
            }
            return false
        }

        // 生物群落：0 开阔地 / 1 掩体区 / 2 树林 / 3 城镇
        let biome: Int
        if isSpawn {
            biome = 0
        } else {
            let r = rnd()
            if r < 0.45 { biome = 0 }
            else if r < 0.75 { biome = 1 }
            else if r < 0.90 { biome = 2 }
            else { biome = 3 }
        }

        // 城镇：楼房
        if biome == 3 {
            let count = rnd() < 0.6 ? 2 : 1
            for _ in 0..<count {
                var attempts = 0
                repeat {
                    let w = rndRange(240, 380), h = rndRange(190, 300)
                    let x = originX + inset + CGFloat(rnd()) * (G.chunkSize - 2 * inset - w)
                    let y = originY + inset + CGFloat(rnd()) * (G.chunkSize - 2 * inset - h)
                    let rect = CGRect(x: x, y: y, width: w, height: h)
                    if !overlapsStructures(rect) {
                        layout.structures.append(Structure(rect: rect, kind: .building)); break
                    }
                    attempts += 1
                } while attempts < 12
            }
            for _ in 0..<3 {
                var attempts = 0
                repeat {
                    let p = interiorPoint(margin: inset)
                    let rect = CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)
                    if !overlapsStructures(rect) {
                        layout.structures.append(Structure(rect: rect, kind: .crate)); break
                    }
                    attempts += 1
                } while attempts < 8
            }
        }

        // 掩体区：沙袋
        if biome == 1 {
            let n = Int(rndRange(5, 9))
            for _ in 0..<n {
                var attempts = 0
                repeat {
                    let horizontal = rnd() < 0.5
                    let w = horizontal ? rndRange(80, 120) : rndRange(26, 32)
                    let h = horizontal ? rndRange(24, 32) : rndRange(80, 120)
                    let p = interiorPoint(margin: inset)
                    let rect = CGRect(x: p.x - w/2, y: p.y - h/2, width: w, height: h)
                    if !overlapsStructures(rect) {
                        layout.structures.append(Structure(rect: rect, kind: .sandbag)); break
                    }
                    attempts += 1
                } while attempts < 10
            }
            if rnd() < 0.5 {
                let p = interiorPoint(margin: inset)
                layout.structures.append(Structure(rect: CGRect(x: p.x-22, y: p.y-22, width: 44, height: 44),
                                                   kind: .crate))
            }
        }

        // 树
        let treeCount: Int
        switch biome {
        case 2: treeCount = Int(rndRange(9, 16))
        case 1: treeCount = Int(rndRange(3, 6))
        default: treeCount = Int(rndRange(2, 5))
        }
        for _ in 0..<treeCount {
            var attempts = 0
            repeat {
                let p = interiorPoint(margin: inset)
                let r = rndRange(16, 26)
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r*2, height: r*2)
                if !overlapsStructures(rect) {
                    layout.structures.append(Structure(rect: rect, kind: .tree)); break
                }
                attempts += 1
            } while attempts < 8
        }

        // 草丛装饰
        let grassCount: Int = biome == 2 ? 12 : Int(rndRange(5, 10))
        for _ in 0..<grassCount {
            let p = interiorPoint(margin: 30)
            layout.grass.append(GrassPatch(pos: p, scale: rndRange(0.7, 1.5)))
        }

        // 掉落物
        if !isSpawn && rnd() < 0.22 {
            let p = interiorPoint(margin: inset)
            let pool: [WeaponID] = WeaponID.allCases.filter { $0 != .glock }
            let w = pool[Int(rnd() * Double(pool.count))]
            layout.pickups.append(PickupSpawn(pos: p, kind: .weapon(w)))
        }
        if !isSpawn && rnd() < 0.30 {
            let p = interiorPoint(margin: inset)
            layout.pickups.append(PickupSpawn(pos: p, kind: .ammo))
        }
        if !isSpawn && rnd() < 0.14 {
            let p = interiorPoint(margin: inset)
            layout.pickups.append(PickupSpawn(pos: p, kind: .medkit))
        }

        return layout
    }
}
