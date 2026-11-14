import SwiftUI

@main
struct MiPlugApp: App {

    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}

enum AppTab: Hashable {
    case control
    case timer
    case scenes
    case history
    case settings
}

struct RootView: View {

    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: AppTab = .control

    var body: some View {
        TabView(selection: $tab) {
            ControlScreen()
                .tabItem { Label("插座", systemImage: "powerplug") }
                .tag(AppTab.control)
                .onAppear { model.refreshOnLaunch() }

            TimerScreen()
                .tabItem { Label("定时", systemImage: "clock") }
                .tag(AppTab.timer)

            ScenesScreen()
                .tabItem { Label("场景", systemImage: "sparkles") }
                .tag(AppTab.scenes)

            HistoryScreen()
                .tabItem { Label("记录", systemImage: "doc.text") }
                .tag(AppTab.history)

            SettingsScreen()
                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
        }
        // 选中态近黑无彩色（极简风硬规则）；不设等于留系统默认蓝
        .tint(NativeUI.ink)
        .overlay(alignment: .top) {
            toastOverlay
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                model.refresh()
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let text = model.toastText {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.75), in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation(.easeOut(duration: 0.2)) { model.toastText = nil }
                }
        }
    }
}
