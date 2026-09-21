import SwiftUI
import SpriteKit
import AppKit

enum Screen {
    case mainMenu, saveSelect, playing, paused, dead
}

final class AppState: ObservableObject {
    @Published var screen: Screen = .mainMenu
    @Published var slots: [SlotInfo] = []
    @Published var currentSlot: Int? = nil
    @Published var deathScore = 0
    @Published var deathKills = 0
    @Published var deathTime: TimeInterval = 0

    var scene: GameScene?
    private var isDead = false
    private var cursorHidden = false

    init() {
        let s = GameScene(size: CGSize(width: 1280, height: 800))
        s.appState = self
        self.scene = s
        refreshSlots()
    }

    // MARK: - 光标显隐
    private func setCursor(hidden: Bool) {
        if hidden && !cursorHidden { NSCursor.hide(); cursorHidden = true }
        else if !hidden && cursorHidden { NSCursor.unhide(); cursorHidden = false }
    }

    // MARK: - 存档
    func refreshSlots() {
        slots = SaveManager.shared.list()
    }

    func saveCurrentSilently() {
        guard !isDead, let s = currentSlot, let scene = scene else { return }
        do {
            try SaveManager.shared.save(s, scene.makeSaveData())
        } catch {
            // 静默失败
        }
    }

    func saveAndRefresh() {
        saveCurrentSilently()
        refreshSlots()
    }

    func deleteSlot(_ slot: Int) {
        try? SaveManager.shared.delete(slot)
        refreshSlots()
    }

    // MARK: - 流程
    func showSaveSelect() { refreshSlots(); screen = .saveSelect }

    func startNewGame(slot: Int) {
        currentSlot = slot
        isDead = false
        scene?.startNewGame()
        screen = .playing
        scene?.isPaused = false
        setCursor(hidden: true)
    }

    func continueGame(slot: Int) {
        guard let data = SaveManager.shared.load(slot) else { return }
        currentSlot = slot
        isDead = false
        scene?.loadGame(data)
        screen = .playing
        scene?.isPaused = false
        setCursor(hidden: true)
    }

    func pauseGame() {
        guard screen == .playing else { return }
        screen = .paused
        scene?.isPaused = true
        setCursor(hidden: false)
    }

    func resumeGame() {
        guard screen == .paused else { return }
        screen = .playing
        scene?.isPaused = false
        setCursor(hidden: true)
    }

    func onDeath(score: Int, kills: Int, time: TimeInterval) {
        deathScore = score
        deathKills = kills
        deathTime = time
        isDead = true
        screen = .dead
        scene?.isPaused = true
        setCursor(hidden: false)
    }

    func quitToMenu() {
        saveCurrentSilently()
        screen = .mainMenu
        scene?.isPaused = true
        setCursor(hidden: false)
    }
}
