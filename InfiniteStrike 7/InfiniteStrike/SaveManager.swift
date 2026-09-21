import Foundation

final class SaveManager {
    static let shared = SaveManager()
    let directory: URL

    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? URL(fileURLWithPath: NSHomeDirectory())
        directory = base.appendingPathComponent("InfiniteStrike/saves", isDirectory: true)
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(_ slot: Int) -> URL {
        directory.appendingPathComponent("slot_\(slot).json")
    }

    func save(_ slot: Int, _ data: SaveData) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let encoded = try encoder.encode(data)
        try encoded.write(to: fileURL(slot), options: .atomic)
    }

    func load(_ slot: Int) -> SaveData? {
        guard let data = try? Data(contentsOf: fileURL(slot)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SaveData.self, from: data)
    }

    func delete(_ slot: Int) throws {
        try FileManager.default.removeItem(at: fileURL(slot))
    }

    func list() -> [SlotInfo] {
        (0..<10).map { i in
            if let d = load(i) {
                return SlotInfo(index: i, exists: true,
                                score: d.score, kills: d.kills,
                                time: d.time, date: d.savedAt)
            }
            return SlotInfo(index: i, exists: false)
        }
    }
}
