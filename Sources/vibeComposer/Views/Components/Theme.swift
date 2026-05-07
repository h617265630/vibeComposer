import SwiftUI

enum BackgroundThemeMode: String, CaseIterable, Identifiable {
    case black
    case white

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: "黑色"
        case .white: "白色"
        }
    }

    var commandTitle: String {
        switch self {
        case .black: "黑色主题"
        case .white: "白色主题"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .black: .dark
        case .white: .light
        }
    }

    var palette: VibeThemePalette {
        switch self {
        case .black:
            VibeThemePalette(
                background: Color(red: 0.055, green: 0.058, blue: 0.066),
                panel: Color(red: 0.085, green: 0.089, blue: 0.102),
                panelAlt: Color(red: 0.115, green: 0.120, blue: 0.140),
                border: Color.white.opacity(0.08)
            )
        case .white:
            VibeThemePalette(
                background: Color(red: 0.965, green: 0.968, blue: 0.974),
                panel: Color.white,
                panelAlt: Color(red: 0.928, green: 0.936, blue: 0.946),
                border: Color.black.opacity(0.10)
            )
        }
    }

    static func mode(for rawValue: String) -> BackgroundThemeMode {
        BackgroundThemeMode(rawValue: rawValue) ?? .black
    }
}

struct VibeThemePalette: Equatable {
    let background: Color
    let panel: Color
    let panelAlt: Color
    let border: Color
}

private struct VibeThemePaletteKey: EnvironmentKey {
    static let defaultValue = BackgroundThemeMode.black.palette
}

extension EnvironmentValues {
    var vibeTheme: VibeThemePalette {
        get { self[VibeThemePaletteKey.self] }
        set { self[VibeThemePaletteKey.self] = newValue }
    }
}

enum VibeTheme {
    static let background = Color(red: 0.055, green: 0.058, blue: 0.066)
    static let panel = Color(red: 0.085, green: 0.089, blue: 0.102)
    static let panelAlt = Color(red: 0.115, green: 0.120, blue: 0.140)
    static let border = Color.white.opacity(0.08)
    static let accent = Color(red: 0.30, green: 0.72, blue: 0.92)
    static let green = Color(red: 0.32, green: 0.78, blue: 0.52)
    static let amber = Color(red: 0.93, green: 0.67, blue: 0.32)
    static let red = Color(red: 0.92, green: 0.36, blue: 0.36)
}

struct Card<Content: View>: View {
    @Environment(\.vibeTheme) private var theme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    var color: Color = VibeTheme.accent

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct StatusBadge: View {
    let text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct EmptyState: View {
    let title: String
    let detail: String
    var symbol: String = "folder.badge.questionmark"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

extension ProgressStatus {
    var color: Color {
        switch self {
        case .done: VibeTheme.green
        case .baseline: VibeTheme.accent
        case .inProgress: VibeTheme.accent
        case .needsReview: VibeTheme.amber
        case .redo: VibeTheme.red
        case .risk: VibeTheme.red
        }
    }
}

extension VibeRuleSeverity {
    var color: Color {
        switch self {
        case .info: VibeTheme.accent
        case .warning: VibeTheme.amber
        case .error: VibeTheme.red
        }
    }
}

extension VibeWorkflowStepStatus {
    var color: Color {
        switch self {
        case .done: VibeTheme.green
        case .active: VibeTheme.accent
        case .blocked: VibeTheme.red
        case .pending: .secondary
        }
    }
}
