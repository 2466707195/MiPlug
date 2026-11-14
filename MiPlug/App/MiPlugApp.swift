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
    case settings
}

struct RootView: View {

    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: AppTab = .control

    var body: some View {
        TabView(selection: $tab) {
            ControlScreen()
                .tabItem { Label("插座", systemImage: "powerplug.fill") }
                .tag(AppTab.control)
                .onAppear { model.refreshOnLaunch() }

            SettingsScreen()
                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
        }
        // 选中态近黑无彩色（极简风硬规则）；不设等于留系统默认蓝
        .tint(NativeUI.ink)
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                model.refresh()
            }
        }
    }
}
