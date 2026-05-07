import SwiftUI

struct RuleIssueRow: View {
    @EnvironmentObject private var store: ProjectStore
    let check: VibeRuleCheck

    private var canRepair: Bool {
        HarnessService.canRepairTrackRegistration(check)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                StatusBadge(text: check.severity == .error ? "Error" : check.severity == .warning ? "Warning" : "Info", color: check.severity.color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(check.title)
                        .font(.subheadline.weight(.semibold))
                    Text(check.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Text(check.target)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if canRepair {
                    Button {
                        store.repairTrackRegistration(for: check)
                    } label: {
                        Label("添加到 track", systemImage: "text.badge.plus")
                    }
                }
                Button {
                    store.openTrackFile()
                } label: {
                    Label("打开 track", systemImage: "doc.text")
                }
                Button {
                    store.copyFixPrompt(for: check)
                } label: {
                    Label("复制指令", systemImage: "doc.on.doc")
                }
                Button {
                    store.refresh()
                } label: {
                    Label("重新检查", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 5)
    }
}

struct QualityIssueRow: View {
    @EnvironmentObject private var store: ProjectStore
    let check: CodeQualityCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                StatusBadge(text: check.severity.label, color: check.severity == .error ? VibeTheme.red : check.severity == .warning ? VibeTheme.amber : VibeTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(check.message)
                        .font(.subheadline.weight(.semibold))
                    Text("\(check.file)\(check.line.map { ":\($0)" } ?? "")")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let suggestion = check.suggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    store.openQualityIssue(check)
                } label: {
                    Label("打开文件", systemImage: "doc.text.magnifyingglass")
                }
                Button {
                    store.copyFixPrompt(for: check)
                } label: {
                    Label("复制指令", systemImage: "doc.on.doc")
                }
                Button {
                    store.refresh()
                } label: {
                    Label("重新检查", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 5)
    }
}
