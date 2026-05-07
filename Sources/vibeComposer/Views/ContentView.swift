import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore
    @AppStorage("backgroundThemeMode") private var backgroundThemeModeRaw = BackgroundThemeMode.black.rawValue
    @State private var showingOnboarding = false

    var body: some View {
        let theme = BackgroundThemeMode.mode(for: backgroundThemeModeRaw).palette
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(theme.border)
            VStack(spacing: 0) {
                topBar
                Divider().overlay(theme.border)
                detail
            }
            .background(theme.background)
        }
        .background(theme.background)
        .environment(\.vibeTheme, theme)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                showingOnboarding = false
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .foregroundStyle(VibeTheme.accent)
                    Text("vibeComposer")
                        .font(.title3.weight(.semibold))
                }
                Text(store.projectURL?.lastPathComponent ?? "No project selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            List(selection: $store.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                // 当前轮次状态
                if let round = store.data.controlState.currentRound {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(VibeTheme.accent)
                            .frame(width: 6, height: 6)
                        Text("轮次: \(round.title)")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }

                StatusBadge(text: store.data.vibeHarness.isComplete ? "Harness Ready" : "Harness Missing", color: store.data.vibeHarness.isComplete ? VibeTheme.green : VibeTheme.amber)
                Text(store.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Divider()
                    .frame(height: 8)

                // 使用指南按钮
                Button {
                    showingOnboarding = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.open")
                            .font(.caption)
                        Text("使用指南")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(VibeTheme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .frame(width: 228)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedTab.title)
                    .font(.title2.weight(.semibold))
                Text(store.data.vibeInventory.projectName.isEmpty ? "选择本地项目后开始追踪" : store.data.vibeInventory.projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                store.chooseProjectFolder()
            } label: {
                Label("打开项目", systemImage: "folder")
            }
            Button {
                store.refresh()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            Button {
                store.generateHarness()
            } label: {
                Label("生成 Harness", systemImage: "wand.and.stars")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var detail: some View {
        if let error = store.errorMessage {
            EmptyState(title: "出现错误", detail: error, symbol: "exclamationmark.triangle")
        } else if store.projectURL == nil {
            EmptyState(title: "打开一个项目文件夹", detail: "vibeComposer 会扫描 Git、文件变更、项目结构、前端页面、后端 API、数据库、AI Logic 和 .vibe harness。")
        } else {
            let progress = ProgressDeriver.derive(from: store.data)
            switch store.selectedTab {
            case .overview:
                OverviewView(data: store.data, progress: progress)
            case .board:
                ProjectBoardView(data: store.data, progress: progress)
            case .aiWork:
                AiWorkView(progress: progress)
            case .control:
                ControlCenterView(progress: progress)
            case .generations:
                GenerationRecordsView()
            case .alignment:
                AlignmentAnalysisView()
            case .rounds:
                RoundsHistoryView()
            case .technical:
                TechnicalDetailsView(data: store.data)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ProjectStore
    @AppStorage("backgroundThemeMode") private var backgroundThemeModeRaw = BackgroundThemeMode.black.rawValue

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("背景", selection: $backgroundThemeModeRaw) {
                    ForEach(BackgroundThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Project") {
                Text(store.projectURL?.path ?? "No project selected")
                Button("Open Project Folder...") {
                    store.chooseProjectFolder()
                }
            }
            Section("Refresh") {
                Text("vibeComposer refreshes every 30 seconds and on demand.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 460)
    }
}
