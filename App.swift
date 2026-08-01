import SwiftUI

@main
struct OverdriveApp: App {
    @StateObject private var brain = BoostBrain()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                List(Tab.allCases, selection: $brain.tab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 160, ideal: 185, max: 220)

                VStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill").font(.system(size: 9))
                            .foregroundStyle(T.boost)
                        Text("OVERDRIVE").font(.system(size: 9, weight: .bold)).tracking(1)
                            .foregroundStyle(T.textDim)
                    }
                    .padding(.bottom, 12)
                }
            } detail: {
                Group {
                    switch brain.tab {
                    case .dashboard: DashboardView(brain: brain)
                    case .benchmark: BenchmarkView(brain: brain)
                    default:
                        if let cat = Category(rawValue: brain.tab.rawValue) ??
                            categoryFor(brain.tab) {
                            SubsystemView(brain: brain, category: cat)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 920, minHeight: 620)
            .onAppear { brain.start() }
            .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 680)
    }

    func categoryFor(_ tab: Tab) -> Category? {
        switch tab {
        case .power: return .power
        case .ram: return .ram
        case .ssd: return .ssd
        case .network: return .network
        case .ui: return .ui
        case .background: return .background
        default: return nil
        }
    }
}
