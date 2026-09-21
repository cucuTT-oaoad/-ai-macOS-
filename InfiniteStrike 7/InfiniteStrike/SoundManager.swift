import AVFoundation
import Foundation

// 合成音效（无需外部音频资源）
final class SoundManager {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]

    private init() { build() }

    struct LCG {
        private var s: UInt64
        init(seed: UInt64) { s = seed }
        mutating func noise() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 32) / 4294967296.0 * 2.0 - 1.0
        }
    }

    private func wav(duration: Double, volume: Double,
                     _ gen: (Double, inout LCG) -> Double) -> Data {
        let rate: Int = 22050
        let n = Int(duration * Double(rate))
        var lcg = LCG(seed: 0xC0FFEE)
        var samples = [Int16](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(rate)
            var v = gen(t, &lcg)
            v = max(-1, min(1, v * volume))
            samples[i] = Int16(v * 32000)
        }
        var data = Data()
        func append(_ s: String) { if let d = s.data(using: .ascii) { data.append(contentsOf: d) } }
        func append32(_ v: UInt32) { var v = v; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { var v = v; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        let dataSize = UInt32(n * 2)
        append("RIFF"); append32(36 + dataSize); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(1)
        append32(UInt32(rate)); append32(UInt32(rate * 2)); append16(2); append16(16)
        append("data"); append32(dataSize)
        samples.withUnsafeBytes { raw in
            data.append(contentsOf: raw.bindMemory(to: UInt8.self))
        }
        return data
    }

    private func build() {
        func make(_ name: String, _ data: Data) {
            if let p = try? AVAudioPlayer(data: data) {
                p.prepareToPlay()
                players[name] = p
            }
        }
        make("shot_glock", wav(duration: 0.10, volume: 0.55, noiseShot(0.10, 0.5)))
        make("shot_mp5",   wav(duration: 0.12, volume: 0.55, noiseShot(0.12, 0.4)))
        make("shot_ak",    wav(duration: 0.20, volume: 0.70, noiseShot(0.20, 0.8)))
        make("shot_m4",    wav(duration: 0.14, volume: 0.55, noiseShot(0.14, 0.5)))
        make("shot_spas",  wav(duration: 0.30, volume: 0.85, noiseShot(0.30, 1.0)))
        make("shot_awm",   wav(duration: 0.40, volume: 0.85, noiseShot(0.40, 1.0)))
        make("enemy_shot", wav(duration: 0.10, volume: 0.30, noiseShot(0.10, 0.3)))
        make("hit",    wav(duration: 0.05, volume: 0.4, hitGen))
        make("kill",   wav(duration: 0.18, volume: 0.5, killGen))
        make("hurt",   wav(duration: 0.14, volume: 0.5, hurtGen))
        make("reload", wav(duration: 0.25, volume: 0.4, reloadGen))
        make("pickup", wav(duration: 0.18, volume: 0.4, pickupGen))
        make("empty",  wav(duration: 0.06, volume: 0.3, emptyGen))
        make("medkit", wav(duration: 0.28, volume: 0.4, medkitGen))
    }

    private typealias Gen = (Double, inout LCG) -> Double

    private func noiseShot(_ dur: Double, _ thump: Double) -> Gen {
        { (t: Double, lcg: inout LCG) -> Double in
            let env = exp(-t / (dur * 0.4))
            let noise = lcg.noise() * env
            let low = sin(2 * .pi * 90 * t) * exp(-t / (dur * 0.25)) * thump
            return noise * 0.7 + low
        }
    }
    private func hitGen(_ t: Double, _ lcg: inout LCG) -> Double { lcg.noise() * exp(-t * 80) }
    private func killGen(_ t: Double, _ lcg: inout LCG) -> Double {
        let f = 300.0 - 220.0 * (t / 0.18)
        return sin(2 * .pi * f * t) * exp(-t * 12) * 0.6
    }
    private func hurtGen(_ t: Double, _ lcg: inout LCG) -> Double {
        sin(2 * .pi * 150 * t) * exp(-t * 14) * 0.7 + lcg.noise() * exp(-t * 30) * 0.2
    }
    private func reloadGen(_ t: Double, _ lcg: inout LCG) -> Double {
        let c = (abs(t - 0.02) < 0.015 || abs(t - 0.16) < 0.015) ? 1.0 : 0.0
        return lcg.noise() * c * 0.6
    }
    private func pickupGen(_ t: Double, _ lcg: inout LCG) -> Double {
        sin(2 * .pi * (500 + 400 * t / 0.18) * t) * exp(-t * 10) * 0.6
    }
    private func emptyGen(_ t: Double, _ lcg: inout LCG) -> Double { lcg.noise() * exp(-t * 90) }
    private func medkitGen(_ t: Double, _ lcg: inout LCG) -> Double {
        let note = t < 0.09 ? 660.0 : (t < 0.18 ? 880.0 : 1100.0)
        return sin(2 * .pi * note * t) * exp(-t * 8) * 0.5
    }

    func play(_ name: String) {
        guard let p = players[name] else { return }
        p.currentTime = 0
        p.play()
    }
}
