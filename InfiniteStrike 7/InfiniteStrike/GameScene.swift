import SpriteKit
import AppKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: 碰撞分类
    private struct Cat {
        static let player: UInt32 = 0b1
        static let playerBullet: UInt32 = 0b10
        static let enemy: UInt32 = 0b100
        static let enemyBullet: UInt32 = 0b1000
        static let structure: UInt32 = 0b10000
        static let pickup: UInt32 = 0b100000
    }

    weak var appState: AppState?

    // MARK: 节点
    private var worldNode = SKNode()
    private var cameraNode = SKCameraNode()
    private var hud = SKNode()
    private var player: SKSpriteNode!
    private var crosshair: SKSpriteNode!

    private var chunks: [ChunkKey: SKNode] = [:]
    private var layouts: [ChunkKey: ChunkLayout] = [:]
    private var pickupKinds: [SKNode: PickupKind] = [:]

    // MARK: 玩家状态
    private var seed: UInt64 = 1
    private var hp: Double = G.maxHP
    private var score = 0
    private var kills = 0
    private var playTime: TimeInterval = 0
    private var owned: Set<WeaponID> = [.glock]
    private var currentWeapon: WeaponID = .glock
    private var mags: [WeaponID: Int] = [:]
    private var reserves: [WeaponID: Int] = [:]

    // MARK: 输入与计时
    private var keys = Set<UInt16>()
    private var firing = false
    private var aimPoint = CGPoint.zero
    private var lastFrame: TimeInterval = 0
    private var fireCooldown: TimeInterval = 0
    private var emptyCooldown: TimeInterval = 0
    private var reloadTimer: TimeInterval = 0
    private var reloadPending: Bool = false
    private var streamTimer: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var autosaveTimer: TimeInterval = 0
    private var didSetup = false

    // MARK: 实体
    private struct EnemyState { var type: EnemyType; var hp: Double; var cooldown: TimeInterval }
    private enum EnemyType { case grunt, runner, shooter }
    private var enemies: [SKNode: EnemyState] = [:]

    private struct BulletInfo { var damage: Double; var range: CGFloat; var start: CGPoint; var fromPlayer: Bool }
    private var bullets: [SKNode: BulletInfo] = [:]

    // MARK: HUD
    private var hpBarBG: SKSpriteNode!
    private var hpBar: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var killsLabel: SKLabelNode!
    private var weaponLabel: SKLabelNode!
    private var ammoLabel: SKLabelNode!
    private var timerLabel: SKLabelNode!
    private var hpLabel: SKLabelNode!
    private var hintLabel: SKLabelNode!
    private var slotBoxes: [SKShapeNode] = []

    private var eventTokens: [Any] = []

    // MARK: 初始化
    override init(size: CGSize) {
        super.init(size: size)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = NSColor(red: 0.18, green: 0.22, blue: 0.16, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        scaleMode = .resizeFill

        addChild(worldNode)

        player = SKSpriteNode(texture: Art.player)
        player.zPosition = 15
        player.physicsBody = SKPhysicsBody(circleOfRadius: 13)
        player.physicsBody!.categoryBitMask = Cat.player
        player.physicsBody!.collisionBitMask = Cat.structure
        player.physicsBody!.contactTestBitMask = Cat.enemyBullet | Cat.pickup
        player.physicsBody!.affectedByGravity = false
        player.physicsBody!.allowsRotation = false
        player.physicsBody!.linearDamping = 0
        worldNode.addChild(player)

        crosshair = SKSpriteNode(texture: Art.crosshair)
        crosshair.zPosition = 100
        addChild(crosshair)

        addChild(cameraNode)
        camera = cameraNode
        buildHUD()

        // 事件监听（不依赖第一响应者）
        let kd = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handleKeyDown(e); return e
        }
        let ku = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] e in
            self?.keys.remove(e.keyCode); return e
        }
        let md = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
            self?.firing = true; return e
        }
        let mu = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] e in
            self?.firing = false; return e
        }
        eventTokens = [kd as Any, ku as Any, md as Any, mu as Any]

        didSetup = true
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        for t in eventTokens { NSEvent.removeMonitor(t) }
        eventTokens.removeAll()
    }

    // MARK: 输入
    private func handleKeyDown(_ e: NSEvent) {
        keys.insert(e.keyCode)
        guard let app = appState else { return }
        let code = e.keyCode
        if code == 53 { // Esc
            if app.screen == .playing { app.pauseGame() }
            else if app.screen == .paused { app.resumeGame() }
            return
        }
        guard app.screen == .playing else { return }
        if code == 15 { startReload() } // R
        let digitMap: [UInt16: WeaponID] = [18: .glock, 19: .mp5, 20: .ak47,
                                            21: .m4a1, 23: .spas12, 22: .awm]
        if let w = digitMap[code] { switchWeapon(w) }
    }

    // MARK: 开局 / 读档
    func startNewGame() {
        seed = UInt64.random(in: 1...UInt64.max)
        resetWorld(playerPos: .zero, restore: nil)
    }

    func loadGame(_ data: SaveData) {
        seed = data.seed
        resetWorld(playerPos: CGPoint(x: data.playerX, y: data.playerY), restore: data)
    }

    private func resetWorld(playerPos: CGPoint, restore: SaveData?) {
        for (_, node) in chunks { node.removeFromParent() }
        chunks.removeAll(); layouts.removeAll(); pickupKinds.removeAll()
        for (node, _) in enemies { node.removeFromParent() }
        enemies.removeAll()
        for (node, _) in bullets { node.removeFromParent() }
        bullets.removeAll()

        hp = G.maxHP; score = 0; kills = 0; playTime = 0
        owned = Set(WeaponID.allCases)
        currentWeapon = .glock
        mags.removeAll(); reserves.removeAll()
        for w in WeaponID.allCases {
            mags[w] = w.def.magSize
            reserves[w] = w.def.reserveAmount
        }
        reloadPending = false; reloadTimer = 0; fireCooldown = 0; lastFrame = 0
        player.isHidden = false

        if let d = restore {
            hp = d.hp; score = d.score; kills = d.kills; playTime = d.time
            owned = Set(d.owned.compactMap(WeaponID.init(rawValue:)))
            if !owned.contains(.glock) { owned.insert(.glock) }
            currentWeapon = WeaponID(rawValue: d.currentWeapon) ?? .glock
            mags.removeAll(); reserves.removeAll()
            for (k, v) in d.mags { if let w = WeaponID(rawValue: k) { mags[w] = v } }
            for (k, v) in d.reserves { if let w = WeaponID(rawValue: k) { reserves[w] = v } }
            for w in owned {
                if mags[w] == nil { mags[w] = 0 }
                if reserves[w] == nil { reserves[w] = 0 }
            }
        }

        player.position = playerPos
        positionPlayerSafely()
        cameraNode.position = player.position
        streamChunks()
        updateHUD()
    }

    func makeSaveData() -> SaveData {
        SaveData(seed: seed,
                 playerX: Double(player.position.x),
                 playerY: Double(player.position.y),
                 hp: max(0, hp),
                 score: score, kills: kills, time: playTime,
                 owned: owned.map { $0.rawValue },
                 currentWeapon: currentWeapon.rawValue,
                 mags: Dictionary(uniqueKeysWithValues: mags.map { ($0.rawValue, $1) }),
                 reserves: Dictionary(uniqueKeysWithValues: reserves.map { ($0.rawValue, $1) }),
                 savedAt: Date())
    }

    // MARK: 区块世界
    private func chunkCoord(_ p: CGPoint) -> (Int, Int) {
        (Int(floor(p.x / G.chunkSize)), Int(floor(p.y / G.chunkSize)))
    }

    func isClear(_ p: CGPoint, pad: CGFloat) -> Bool {
        let (cx, cy) = chunkCoord(p)
        guard let layout = layouts[ChunkKey(cx: cx, cy: cy)] else { return true }
        for s in layout.structures {
            if s.kind == .tree {
                let dx = p.x - s.rect.midX, dy = p.y - s.rect.midY
                let rr = s.rect.width / 2 + pad
                if dx*dx + dy*dy < rr*rr { return false }
            } else {
                if s.rect.insetBy(dx: -pad, dy: -pad).contains(p) { return false }
            }
        }
        return true
    }

    private func positionPlayerSafely() {
        if isClear(player.position, pad: 26) { return }
        for r in stride(from: 60.0, through: 800.0, by: 40.0) {
            for a in stride(from: 0.0, through: .pi * 2, by: .pi / 6) {
                let p = CGPoint(x: player.position.x + CGFloat(cos(a)) * CGFloat(r),
                                y: player.position.y + CGFloat(sin(a)) * CGFloat(r))
                if isClear(p, pad: 26) { player.position = p; return }
            }
        }
    }

    func streamChunks() {
        let (pcx, pcy) = chunkCoord(player.position)
        let R = 2
        for dx in -R...R {
            for dy in -R...R {
                let key = ChunkKey(cx: pcx + dx, cy: pcy + dy)
                if chunks[key] == nil { loadChunk(key) }
            }
        }
        var stale: [ChunkKey] = []
        for (key, node) in chunks {
            if abs(key.cx - pcx) > R + 1 || abs(key.cy - pcy) > R + 1 {
                for child in node.children { pickupKinds[child] = nil }
                node.removeFromParent()
                stale.append(key)
            }
        }
        for key in stale {
            chunks[key] = nil
            layouts[key] = nil
        }
    }

    private func loadChunk(_ key: ChunkKey) {
        let layout = WorldGenerator.generate(seed: seed, cx: key.cx, cy: key.cy)
        let group = SKNode()
        let ox = CGFloat(key.cx) * G.chunkSize
        let oy = CGFloat(key.cy) * G.chunkSize

        let ground = SKSpriteNode(texture: Art.groundTexture(layout.groundTexture))
        ground.position = CGPoint(x: ox + G.chunkSize/2, y: oy + G.chunkSize/2)
        ground.size = CGSize(width: G.chunkSize, height: G.chunkSize)
        group.addChild(ground)

        for g in layout.grass {
            let n = SKSpriteNode(texture: Art.grass)
            n.position = g.pos
            n.setScale(g.scale)
            n.zPosition = 1
            group.addChild(n)
        }

        for s in layout.structures {
            switch s.kind {
            case .building:
                let n = SKSpriteNode(texture: Art.buildingTexture(w: s.rect.width, h: s.rect.height))
                n.position = CGPoint(x: s.rect.midX, y: s.rect.midY)
                n.zPosition = 5
                attachStatic(n, size: s.rect.size)
                group.addChild(n)
            case .sandbag:
                let horizontal = s.rect.width >= s.rect.height
                let n = SKSpriteNode(texture: horizontal ? Art.sandbagH : Art.sandbagV)
                n.position = CGPoint(x: s.rect.midX, y: s.rect.midY)
                n.size = s.rect.size
                n.zPosition = 5
                attachStatic(n, size: s.rect.size)
                group.addChild(n)
            case .crate:
                let n = SKSpriteNode(texture: Art.crate)
                n.position = CGPoint(x: s.rect.midX, y: s.rect.midY)
                n.zPosition = 5
                attachStatic(n, size: s.rect.size)
                group.addChild(n)
            case .tree:
                let r = s.rect.width / 2
                let n = SKSpriteNode(texture: Art.tree)
                n.position = CGPoint(x: s.rect.midX, y: s.rect.midY)
                n.setScale(r / 26.0)
                n.zPosition = 5
                let body = SKPhysicsBody(circleOfRadius: r * 0.7)
                body.categoryBitMask = Cat.structure
                body.collisionBitMask = 0xFFFFFFFF
                body.isDynamic = false
                n.physicsBody = body
                group.addChild(n)
            }
        }

        for p in layout.pickups {
            let n: SKSpriteNode
            switch p.kind {
            case .weapon: n = SKSpriteNode(texture: Art.weaponCrate)
            case .ammo: n = SKSpriteNode(texture: Art.ammoBox)
            case .medkit: n = SKSpriteNode(texture: Art.medkit)
            }
            n.position = p.pos
            n.zPosition = 3
            attachPickup(n)
            pickupKinds[n] = p.kind
            group.addChild(n)
        }

        worldNode.addChild(group)
        chunks[key] = group
        layouts[key] = layout
    }

    private func attachStatic(_ n: SKNode, size: CGSize) {
        let body = SKPhysicsBody(rectangleOf: size)
        body.categoryBitMask = Cat.structure
        body.collisionBitMask = 0xFFFFFFFF
        body.isDynamic = false
        n.physicsBody = body
    }

    private func attachPickup(_ n: SKNode) {
        let body = SKPhysicsBody(circleOfRadius: 14)
        body.categoryBitMask = Cat.pickup
        body.collisionBitMask = 0
        body.contactTestBitMask = Cat.player
        body.isDynamic = false
        n.physicsBody = body
    }

    // MARK: 主循环
    override func update(_ currentTime: TimeInterval) {
        guard didSetup, appState?.screen == .playing else { return }
        let dt: TimeInterval
        if lastFrame == 0 { dt = 1.0 / 60 } else { dt = min(currentTime - lastFrame, 0.05) }
        lastFrame = currentTime
        playTime += dt

        autosaveTimer += dt
        if autosaveTimer > 30 { autosaveTimer = 0; appState?.saveCurrentSilently() }

        updateAim()
        updatePlayerMovement()
        fireCooldown -= dt
        emptyCooldown -= dt
        if reloadPending {
            reloadTimer -= dt
            if reloadTimer <= 0 { finishReload() }
        }
        tryFire()
        updateEnemies(dt)
        updateBullets()

        streamTimer += dt
        if streamTimer > 0.25 { streamTimer = 0; streamChunks() }
        spawnTimer += dt
        if spawnTimer > 0.6 { spawnTimer = 0; trySpawn() }

        let p = player.position
        cameraNode.position = CGPoint(x: cameraNode.position.x + (p.x - cameraNode.position.x) * 0.15,
                                      y: cameraNode.position.y + (p.y - cameraNode.position.y) * 0.15)
        crosshair.position = aimPoint

        updateHUD()
        if hp <= 0 { die() }
    }

    private func updateAim() {
        guard let view = view, let window = view.window else { return }
        let wp = window.mouseLocationOutsideOfEventStream
        let vp = view.convert(wp, from: nil)
        aimPoint = convertPoint(fromView: vp)
        player.zRotation = atan2(aimPoint.y - player.position.y,
                                 aimPoint.x - player.position.x)
    }

    private func updatePlayerMovement() {
        var dx: CGFloat = 0, dy: CGFloat = 0
        if keys.contains(0) { dx -= 1 }  // A
        if keys.contains(2) { dx += 1 }  // D
        if keys.contains(1) { dy -= 1 }  // S
        if keys.contains(13) { dy += 1 } // W
        let sprint = keys.contains(56) || keys.contains(60)
        let speed: CGFloat = sprint ? 270 : 190
        if dx != 0 || dy != 0 {
            let len = sqrt(dx*dx + dy*dy)
            dx /= len; dy /= len
        }
        player.physicsBody?.velocity = CGVector(dx: dx * speed, dy: dy * speed)
    }

    private func tryFire() {
        let def = currentWeapon.def
        guard firing, !reloadPending else { return }
        if fireCooldown > 0 { return }
        if mags[currentWeapon, default: 0] <= 0 {
            if emptyCooldown <= 0 { SoundManager.shared.play("empty"); emptyCooldown = 0.35 }
            startReload()
            return
        }
        fireCooldown = def.fireInterval
        mags[currentWeapon] = (mags[currentWeapon] ?? 0) - 1
        let angle = player.zRotation
        let spread = CGFloat(def.spreadDeg) * .pi / 180
        for _ in 0..<def.pellets {
            let a = angle + CGFloat.random(in: -spread...spread)
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let from = player.position + CGPoint(x: CGFloat(dir.dx) * 24, y: CGFloat(dir.dy) * 24)
            spawnBullet(from: from, dir: dir, damage: def.damage,
                        speed: def.bulletSpeed, range: def.range, fromPlayer: true)
        }
        let flash = SKSpriteNode(texture: Art.flash)
        flash.position = player.position + CGPoint(x: cos(angle) * 28, y: sin(angle) * 28)
        flash.zPosition = 50
        flash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.06),
                                     SKAction.removeFromParent()]))
        worldNode.addChild(flash)
        SoundManager.shared.play(def.soundName)
    }

    private func spawnBullet(from pos: CGPoint, dir: CGVector,
                             damage: Double, speed: CGFloat, range: CGFloat,
                             fromPlayer: Bool) {
        let n = SKSpriteNode(texture: fromPlayer ? Art.bulletP : Art.bulletE)
        n.position = pos
        n.zPosition = 20
        let body = SKPhysicsBody(circleOfRadius: 3)
        body.affectedByGravity = false
        body.linearDamping = 0
        body.usesPreciseCollisionDetection = true
        body.velocity = CGVector(dx: dir.dx * speed, dy: dir.dy * speed)
        if fromPlayer {
            body.categoryBitMask = Cat.playerBullet
            body.collisionBitMask = Cat.structure
            body.contactTestBitMask = Cat.enemy | Cat.structure
        } else {
            body.categoryBitMask = Cat.enemyBullet
            body.collisionBitMask = Cat.structure
            body.contactTestBitMask = Cat.player | Cat.structure
        }
        n.physicsBody = body
        worldNode.addChild(n)
        bullets[n] = BulletInfo(damage: damage, range: range, start: pos, fromPlayer: fromPlayer)
    }

    private func updateBullets() {
        for node in Array(bullets.keys) {
            guard let info = bullets[node] else { continue }
            let dx = node.position.x - info.start.x
            let dy = node.position.y - info.start.y
            if dx*dx + dy*dy > info.range*info.range {
                node.removeFromParent()
                bullets[node] = nil
            }
        }
    }

    // MARK: 敌人
    private func difficulty() -> Int {
        1 + Int(playTime / 45) + kills / 12
    }

    private func trySpawn() {
        let cap = min(12 + difficulty() * 2, 36)
        if enemies.count >= cap { return }
        for _ in 0..<10 {
            let a = CGFloat.random(in: 0...(.pi * 2))
            let r = CGFloat.random(in: 320...700)
            let p = CGPoint(x: player.position.x + cos(a) * r,
                            y: player.position.y + sin(a) * r)
            if isClear(p, pad: 20) { spawnEnemy(p); return }
        }
    }

    private func spawnEnemy(_ p: CGPoint) {
        let roll = Double.random(in: 0...1)
        let type: EnemyType
        if roll < 0.55 { type = .grunt }
        else if roll < 0.75 { type = .runner }
        else { type = .shooter }
        let hpMult = 1 + 0.08 * Double(difficulty() - 1)
        let spr: SKSpriteNode
        let hp: Double
        switch type {
        case .grunt: spr = SKSpriteNode(texture: Art.enemyGrunt); hp = 30 * hpMult
        case .runner: spr = SKSpriteNode(texture: Art.enemyRunner); hp = 20 * hpMult
        case .shooter: spr = SKSpriteNode(texture: Art.enemyShooter); hp = 40 * hpMult
        }
        spr.position = p
        spr.zPosition = 10
        let body = SKPhysicsBody(circleOfRadius: 13)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.categoryBitMask = Cat.enemy
        body.collisionBitMask = Cat.structure
        body.contactTestBitMask = Cat.playerBullet
        spr.physicsBody = body
        worldNode.addChild(spr)
        enemies[spr] = EnemyState(type: type, hp: hp, cooldown: 0)
    }

    private func updateEnemies(_ dt: TimeInterval) {
        for node in Array(enemies.keys) {
            guard var s = enemies[node] else { continue }
            s.cooldown -= dt
            let dx = player.position.x - node.position.x
            let dy = player.position.y - node.position.y
            let dist = sqrt(dx*dx + dy*dy)
            node.zRotation = atan2(dy, dx)
            guard dist > 1 else { enemies[node] = s; continue }
            switch s.type {
            case .grunt:
                node.physicsBody?.velocity = CGVector(dx: dx/dist * 90, dy: dy/dist * 90)
                if dist < 34 && s.cooldown <= 0 { damagePlayer(10); s.cooldown = 1.0 }
            case .runner:
                node.physicsBody?.velocity = CGVector(dx: dx/dist * 170, dy: dy/dist * 170)
                if dist < 30 && s.cooldown <= 0 { damagePlayer(8); s.cooldown = 0.8 }
            case .shooter:
                var vx: CGFloat = 0, vy: CGFloat = 0
                if dist > 420 { vx = dx/dist * 70; vy = dy/dist * 70 }
                else if dist < 220 { vx = -dx/dist * 70; vy = -dy/dist * 70 }
                node.physicsBody?.velocity = CGVector(dx: vx, dy: vy)
                if s.cooldown <= 0 && dist < 900 {
                    s.cooldown = 2.3
                    let dir = CGVector(dx: dx/dist, dy: dy/dist)
                    let from = node.position + CGPoint(x: dir.dx * 18, y: dir.dy * 18)
                    spawnBullet(from: from, dir: dir, damage: 8,
                                speed: 280, range: 900, fromPlayer: false)
                    SoundManager.shared.play("enemy_shot")
                }
            }
            enemies[node] = s
            if dist > 2600 {
                node.removeFromParent()
                enemies[node] = nil
            }
        }
    }

    // MARK: 碰撞
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ca = a.categoryBitMask, cb = b.categoryBitMask

        if (ca == Cat.playerBullet && cb == Cat.enemy) ||
           (cb == Cat.playerBullet && ca == Cat.enemy) {
            let bullet = (ca == Cat.playerBullet ? a : b).node
            let enemyNode = (ca == Cat.playerBullet ? b : a).node
            guard let bullet = bullet, let enemyNode = enemyNode,
                  let info = bullets[bullet] else { return }
            bullets[bullet] = nil
            bullet.removeFromParent()
            applyDamage(to: enemyNode, amount: info.damage)
        } else if (ca == Cat.playerBullet && cb == Cat.structure) ||
                  (cb == Cat.playerBullet && ca == Cat.structure) {
            let bullet = (ca == Cat.playerBullet ? a : b).node
            guard let bullet = bullet else { return }
            spark(at: bullet.position)
            bullets[bullet] = nil
            bullet.removeFromParent()
        } else if (ca == Cat.enemyBullet && cb == Cat.player) ||
                  (cb == Cat.enemyBullet && ca == Cat.player) {
            let bullet = (ca == Cat.enemyBullet ? a : b).node
            guard let bullet = bullet else { return }
            if let info = bullets[bullet] { damagePlayer(info.damage) }
            bullets[bullet] = nil
            bullet.removeFromParent()
        } else if (ca == Cat.enemyBullet && cb == Cat.structure) ||
                  (cb == Cat.enemyBullet && ca == Cat.structure) {
            let bullet = (ca == Cat.enemyBullet ? a : b).node
            guard let bullet = bullet else { return }
            bullets[bullet] = nil
            bullet.removeFromParent()
        } else if (ca == Cat.player && cb == Cat.pickup) ||
                  (cb == Cat.player && ca == Cat.pickup) {
            let node = (ca == Cat.pickup ? a : b).node
            guard let n = node else { return }
            collectPickup(n)
        }
    }

    private func applyDamage(to enemy: SKNode, amount: Double) {
        guard var state = enemies[enemy] else { return }
        state.hp -= amount
        enemies[enemy] = state
        if let spr = enemy as? SKSpriteNode {
            spr.run(SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.04),
                SKAction.colorize(with: .white, colorBlendFactor: 0, duration: 0.08)
            ]))
        }
        SoundManager.shared.play("hit")
        if state.hp <= 0 { killEnemy(enemy) }
    }

    private func killEnemy(_ node: SKNode) {
        enemies[node] = nil
        node.removeFromParent()
        score += 1
        kills += 1
        SoundManager.shared.play("kill")
        for _ in 0..<5 {
            let b = SKSpriteNode(texture: Art.blood)
            b.position = node.position
            b.zPosition = 10
            worldNode.addChild(b)
            let dx = CGFloat.random(in: -60...60)
            let dy = CGFloat.random(in: -60...60)
            b.run(SKAction.sequence([SKAction.moveBy(x: dx, y: dy, duration: 0.3),
                                     SKAction.fadeOut(withDuration: 0.2),
                                     SKAction.removeFromParent()]))
        }
    }

    private func damagePlayer(_ amount: Double) {
        hp -= amount
        SoundManager.shared.play("hurt")
        player.run(SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.6, duration: 0.05),
            SKAction.colorize(with: .red, colorBlendFactor: 0, duration: 0.1)
        ]))
    }

    private func collectPickup(_ node: SKNode) {
        let kind = pickupKinds[node]
        pickupKinds[node] = nil
        node.removeFromParent()
        switch kind {
        case .weapon(let w):
            if owned.contains(w) {
                reserves[w] = (reserves[w] ?? 0) + w.def.reserveAmount / 2
                floatText("+\(w.def.name) 备弹", at: node.position)
            } else {
                owned.insert(w)
                mags[w] = w.def.magSize
                reserves[w] = (reserves[w] ?? 0) + w.def.reserveAmount
                floatText("+\(w.def.name)", at: node.position)
            }
            SoundManager.shared.play("pickup")
        case .ammo:
            reserves[currentWeapon] = (reserves[currentWeapon] ?? 0) + 30
            floatText("+弹药", at: node.position)
            SoundManager.shared.play("pickup")
        case .medkit:
            hp = min(G.maxHP, hp + 25)
            floatText("+25 HP", at: node.position)
            SoundManager.shared.play("medkit")
        case .none: break
        }
        updateHUD()
    }

    private func spark(at p: CGPoint) {
        let s = SKSpriteNode(texture: Art.spark)
        s.position = p
        s.zPosition = 20
        worldNode.addChild(s)
        s.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.12),
                                 SKAction.removeFromParent()]))
    }

    private func floatText(_ s: String, at p: CGPoint) {
        let l = SKLabelNode(fontNamed: "Helvetica-Bold")
        l.text = s
        l.fontSize = 16
        l.fontColor = .white
        l.position = p
        l.zPosition = 60
        worldNode.addChild(l)
        l.run(SKAction.sequence([SKAction.moveBy(x: 0, y: 40, duration: 0.8),
                                 SKAction.fadeOut(withDuration: 0.5),
                                 SKAction.removeFromParent()]))
    }

    // MARK: 武器操作
    private func startReload() {
        guard !reloadPending else { return }
        let def = currentWeapon.def
        let need = def.magSize - (mags[currentWeapon] ?? 0)
        let have = reserves[currentWeapon] ?? 0
        guard need > 0, have > 0 else { return }
        reloadPending = true
        reloadTimer = def.reloadTime
        SoundManager.shared.play("reload")
    }

    private func finishReload() {
        let def = currentWeapon.def
        let need = def.magSize - (mags[currentWeapon] ?? 0)
        let have = reserves[currentWeapon] ?? 0
        let take = min(need, have)
        mags[currentWeapon] = (mags[currentWeapon] ?? 0) + take
        reserves[currentWeapon] = have - take
        reloadPending = false
        updateHUD()
    }

    private func switchWeapon(_ w: WeaponID) {
        guard owned.contains(w), w != currentWeapon else { return }
        currentWeapon = w
        reloadPending = false
        fireCooldown = 0.15
        updateHUD()
    }

    private func die() {
        hp = 0
        player.isHidden = true
        appState?.onDeath(score: score, kills: kills, time: playTime)
    }

    // MARK: HUD
    private func buildHUD() {
        hud = SKNode()
        cameraNode.addChild(hud)

        let barW: CGFloat = 220
        hpBarBG = SKSpriteNode(color: NSColor(white: 0, alpha: 0.5),
                               size: CGSize(width: barW + 4, height: 22))
        hud.addChild(hpBarBG)
        hpBar = SKSpriteNode(color: .systemRed, size: CGSize(width: barW, height: 16))
        hud.addChild(hpBar)

        hpLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        hpLabel.text = "HP"
        hpLabel.fontSize = 13
        hpLabel.fontColor = .white
        hud.addChild(hpLabel)

        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        hud.addChild(scoreLabel)

        killsLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        killsLabel.fontSize = 14
        killsLabel.fontColor = .white
        killsLabel.horizontalAlignmentMode = .left
        hud.addChild(killsLabel)

        weaponLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        weaponLabel.fontSize = 18
        weaponLabel.fontColor = .systemYellow
        hud.addChild(weaponLabel)

        ammoLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        ammoLabel.fontSize = 14
        ammoLabel.fontColor = .white
        hud.addChild(ammoLabel)

        timerLabel = SKLabelNode(fontNamed: "Helvetica")
        timerLabel.fontSize = 12
        timerLabel.fontColor = .lightGray
        hud.addChild(timerLabel)

        for w in WeaponID.allCases {
            let box = SKShapeNode(rectOf: CGSize(width: 54, height: 22), cornerRadius: 4)
            box.strokeColor = .gray
            box.fillColor = .clear
            box.lineWidth = 1
            let lab = SKLabelNode(fontNamed: "Helvetica-Bold")
            lab.text = w.def.shortName
            lab.fontSize = 11
            lab.fontColor = .white
            box.addChild(lab)
            hud.addChild(box)
            slotBoxes.append(box)
        }

        hintLabel = SKLabelNode(fontNamed: "Helvetica")
        hintLabel.text = "WASD 移动 | Shift 疾跑 | 鼠标瞄准/左键射击 | R 换弹 | 1-6 切枪 | Esc 暂停"
        hintLabel.fontSize = 11
        hintLabel.fontColor = .lightGray
        hintLabel.horizontalAlignmentMode = .left
        hud.addChild(hintLabel)
    }

    private func updateHUD() {
        let w = size.width, h = size.height
        let barW: CGFloat = 220
        let left: CGFloat = -w/2 + 24
        let right: CGFloat = w/2 - 110
        let top: CGFloat = h/2 - 30
        let bottom: CGFloat = -h/2

        hpBarBG.position = CGPoint(x: left + barW/2, y: top)
        let ratio = max(0, CGFloat(hp / G.maxHP))
        hpBar.size = CGSize(width: barW * ratio, height: 16)
        hpBar.position = CGPoint(x: left + barW/2, y: top)
        hpLabel.position = CGPoint(x: left - 18, y: top - 7)
        hintLabel.position = CGPoint(x: left, y: bottom + 14)

        scoreLabel.position = CGPoint(x: right, y: top + 2)
        scoreLabel.text = "得分 \(score)"
        killsLabel.position = CGPoint(x: right, y: top - 26)
        killsLabel.text = "击杀 \(kills)"
        timerLabel.position = CGPoint(x: 0, y: top + 6)
        timerLabel.text = String(format: "%02d:%02d", Int(playTime) / 60, Int(playTime) % 60)

        weaponLabel.position = CGPoint(x: 0, y: bottom + 40)
        weaponLabel.text = reloadPending ? "\(currentWeapon.def.name) 换弹中…" : currentWeapon.def.name
        ammoLabel.position = CGPoint(x: 0, y: bottom + 18)
        ammoLabel.text = "\(mags[currentWeapon] ?? 0) / \(reserves[currentWeapon] ?? 0)"

        for (i, box) in slotBoxes.enumerated() {
            box.position = CGPoint(x: (CGFloat(i) - 2.5) * 60, y: bottom + 62)
            let w = WeaponID.allCases[i]
            box.alpha = owned.contains(w) ? 1 : 0.25
            box.strokeColor = (w == currentWeapon) ? .systemYellow : .gray
        }
    }
}
