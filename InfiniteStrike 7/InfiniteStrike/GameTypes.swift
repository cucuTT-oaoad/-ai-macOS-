import Foundation
import CoreGraphics

// MARK: - 常量
enum G {
    static let chunkSize: CGFloat = 1600
    static let maxHP: Double = 100
}

extension CGPoint {
    static func + (l: CGPoint, r: CGPoint) -> CGPoint {
        CGPoint(x: l.x + r.x, y: l.y + r.y)
    }
}

// MARK: - 枪械定义（现实中知名型号）
enum WeaponID: Int, CaseIterable, Codable {
    case glock = 0, mp5, ak47, m4a1, spas12, awm
}

struct WeaponDef {
    let name: String
    let shortName: String
    let damage: Double
    let pellets: Int
    let fireInterval: TimeInterval
    let spreadDeg: Double
    let bulletSpeed: CGFloat
    let range: CGFloat
    let magSize: Int
    let reserveAmount: Int
    let reloadTime: TimeInterval
    let soundName: String
}

extension WeaponID {
    var def: WeaponDef {
        switch self {
        case .glock:
            return WeaponDef(name: "Glock 17", shortName: "G17",
                             damage: 24, pellets: 1, fireInterval: 0.16, spreadDeg: 2.0,
                             bulletSpeed: 950, range: 1100, magSize: 17,
                             reserveAmount: 120, reloadTime: 1.2, soundName: "shot_glock")
        case .mp5:
            return WeaponDef(name: "MP5", shortName: "MP5",
                             damage: 13, pellets: 1, fireInterval: 0.085, spreadDeg: 3.0,
                             bulletSpeed: 1000, range: 1000, magSize: 30,
                             reserveAmount: 210, reloadTime: 1.5, soundName: "shot_mp5")
        case .ak47:
            return WeaponDef(name: "AK-47", shortName: "AK",
                             damage: 30, pellets: 1, fireInterval: 0.12, spreadDeg: 4.5,
                             bulletSpeed: 1050, range: 1300, magSize: 30,
                             reserveAmount: 180, reloadTime: 1.9, soundName: "shot_ak")
        case .m4a1:
            return WeaponDef(name: "M4A1", shortName: "M4",
                             damage: 21, pellets: 1, fireInterval: 0.09, spreadDeg: 2.2,
                             bulletSpeed: 1100, range: 1300, magSize: 30,
                             reserveAmount: 210, reloadTime: 1.5, soundName: "shot_m4")
        case .spas12:
            return WeaponDef(name: "SPAS-12", shortName: "SP12",
                             damage: 9, pellets: 8, fireInterval: 0.8, spreadDeg: 7.0,
                             bulletSpeed: 850, range: 620, magSize: 8,
                             reserveAmount: 48, reloadTime: 2.4, soundName: "shot_spas")
        case .awm:
            return WeaponDef(name: "AWM", shortName: "AWM",
                             damage: 150, pellets: 1, fireInterval: 1.2, spreadDeg: 0.0,
                             bulletSpeed: 2200, range: 2200, magSize: 5,
                             reserveAmount: 30, reloadTime: 2.8, soundName: "shot_awm")
        }
    }
}

// MARK: - 存档
struct SaveData: Codable {
    var seed: UInt64
    var playerX: Double
    var playerY: Double
    var hp: Double
    var score: Int
    var kills: Int
    var time: Double
    var owned: [Int]
    var currentWeapon: Int
    var mags: [Int: Int]
    var reserves: [Int: Int]
    var savedAt: Date
}

struct SlotInfo {
    let index: Int
    let exists: Bool
    var score: Int = 0
    var kills: Int = 0
    var time: Double = 0
    var date: Date = Date()
}
