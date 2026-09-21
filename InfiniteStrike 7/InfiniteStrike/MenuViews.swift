import SwiftUI
import SpriteKit
import AppKit

struct RootView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ZStack {
            if let scene = app.scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            }
            switch app.screen {
            case .mainMenu: MainMenuView()
            case .saveSelect: SaveSelectView()
            case .playing: Color.clear
            case .paused: PauseView()
            case .dead: DeathView()
            }
        }
    }
}

// MARK: - 主菜单
struct MainMenuView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.07),
                                   Color(red: 0.16, green: 0.19, blue: 0.12)],
                          startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 26) {
                Text("无限战场")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(.white)
                Text("2D 无限地图射击")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                menuButton("开始游戏") { app.showSaveSelect() }
                menuButton("退出") { NSApplication.shared.terminate(nil) }
                Spacer().frame(height: 60)
                Text("build by oaoad")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 60)
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2).bold()
                .foregroundStyle(.black)
                .frame(width: 220, height: 50)
                .background(Color(red: 0.85, green: 0.75, blue: 0.25))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 存档选择
struct SaveSelectView: View {
    @EnvironmentObject var app: AppState
    private let columns = [GridItem(.flexible(), spacing: 16),
                           GridItem(.flexible(), spacing: 16)]
    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("选择存档")
                    .font(.largeTitle).bold().foregroundStyle(.white)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(app.slots, id: \.index) { slotCard($0) }
                }
                Button { app.screen = .mainMenu } label: {
                    Text("返回")
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
    }

    private func slotCard(_ s: SlotInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("存档 \(s.index + 1)")
                .font(.headline).foregroundStyle(.white)
            if s.exists {
                Text("得分 \(s.score) · 击杀 \(s.kills)")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                Text(timeStr(s.time))
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                HStack {
                    Button { app.continueGame(slot: s.index) } label: {
                        Text("继续").frame(width: 70, height: 28)
                            .background(Color.green.opacity(0.8)).cornerRadius(6)
                    }
                    Button { app.deleteSlot(s.index) } label: {
                        Text("删除").frame(width: 70, height: 28)
                            .background(Color.red.opacity(0.8)).cornerRadius(6)
                    }
                }
                .foregroundStyle(.white).font(.subheadline)
                .buttonStyle(.plain)
            } else {
                Text("空存档").foregroundStyle(.white.opacity(0.5))
                Button { app.startNewGame(slot: s.index) } label: {
                    Text("新建").frame(width: 70, height: 28)
                        .background(Color.blue.opacity(0.8)).cornerRadius(6)
                }
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func timeStr(_ t: Double) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - 暂停
struct PauseView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("已暂停")
                    .font(.largeTitle).bold().foregroundStyle(.white)
                pauseButton("继续") { app.resumeGame() }
                pauseButton("保存进度") { app.saveAndRefresh() }
                pauseButton("返回主菜单") { app.quitToMenu() }
            }
        }
    }
    private func pauseButton(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).frame(width: 200, height: 44)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8).foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 阵亡
struct DeathView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ZStack {
            Color(red: 0.25, green: 0.05, blue: 0.05).opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("你阵亡了")
                    .font(.system(size: 48, weight: .heavy)).foregroundStyle(.red)
                Text("最终得分 \(app.deathScore)")
                    .font(.title).foregroundStyle(.white)
                Text("击杀 \(app.deathKills)")
                    .font(.title2).foregroundStyle(.white)
                Text(String(format: "存活时间 %02d:%02d",
                            Int(app.deathTime) / 60, Int(app.deathTime) % 60))
                    .font(.title3).foregroundStyle(.white.opacity(0.8))
                Button { app.quitToMenu() } label: {
                    Text("返回主菜单").frame(width: 220, height: 48)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8).foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
