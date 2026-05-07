import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct VibeComposerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ProjectStore()
    @AppStorage("backgroundThemeMode") private var backgroundThemeModeRaw = BackgroundThemeMode.black.rawValue
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingOnboarding = false

    var body: some Scene {
        WindowGroup("vibeComposer") {
            ZStack {
                ContentView()
                    .environmentObject(store)
                    .preferredColorScheme(BackgroundThemeMode.mode(for: backgroundThemeModeRaw).colorScheme)
                    .frame(minWidth: 1180, minHeight: 760)

                // 引导页面覆盖层
                if showingOnboarding {
                    OnboardingView {
                        showingOnboarding = false
                        hasSeenOnboarding = true
                    }
                }
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showingOnboarding = true
                }
            }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Project Folder...") {
                    store.chooseProjectFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Refresh Scan") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Generate Vibe Harness") {
                    store.generateHarness()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            CommandGroup(after: .windowArrangement) {
                Picker("Theme", selection: $backgroundThemeModeRaw) {
                    ForEach(BackgroundThemeMode.allCases) { mode in
                        Text(mode.commandTitle)
                            .tag(mode.rawValue)
                    }
                }

                Divider()

                Button("Show Onboarding") {
                    showingOnboarding = true
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
