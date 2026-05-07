import SwiftUI

// MARK: - 验收会话视图

struct ReviewSessionView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var currentIndex = 0
    @State private var notes = ""
    @State private var showingSummary = false

    let session: ReviewSession
    let onComplete: () -> Void

    private var displaySession: ReviewSession {
        store.data.controlState.currentSession ?? session
    }

    var body: some View {
        VStack(spacing: 0) {
            // 进度条
            progressBar

            Divider()

            // 当前项
            if currentIndex < session.items.count {
                currentItemView
            } else {
                completionView
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("验收进度")
                    .font(.headline)
                Spacer()
                Text("\(currentIndex) / \(displaySession.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(currentIndex), total: Double(displaySession.items.count))
                .progressViewStyle(.linear)
                .tint(VibeTheme.green)

            HStack(spacing: 12) {
                statChip("待处理", displaySession.items.filter { $0.decision == nil }.count, VibeTheme.amber)
                statChip("已通过", displaySession.items.filter { $0.decision == .confirmed }.count, VibeTheme.green)
                statChip("需重做", displaySession.items.filter { $0.decision == .redo }.count, VibeTheme.red)
            }
        }
        .padding(16)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    private func statChip(_ title: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var currentItemView: some View {
        VStack(spacing: 0) {
            if let item = currentSessionItem, let originalItem = findOriginalItem(item.targetId) {
                let report = ReviewService.alignmentReport(for: originalItem, in: store.data)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        workbenchHeader(item, originalItem: originalItem, report: report)
                        alignmentSection(report)
                        implementationEvidenceSection(report)
                        gapsAndRisksSection(report)
                        notesSection
                    }
                    .padding(20)
                }

                Divider()

                actionBar(originalItem: originalItem, report: report)
                    .padding(16)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.08))
            } else {
                EmptyState(title: "找不到验收项", detail: "请刷新项目后重新开始验收。", symbol: "questionmark.folder")
            }
        }
    }

    private func kindBadge(_ kind: String) -> some View {
        let (text, icon): (String, String) = {
            switch kind {
            case "page": return ("页面", "rectangle.on.rectangle")
            case "feature": return ("功能", "star")
            case "system": return ("系统", "gearshape.2")
            default: return (kind, "questionmark.circle")
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VibeTheme.accent.opacity(0.15))
        .foregroundStyle(VibeTheme.accent)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func originalItemInfo(_ item: TrackableItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.businessMeaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            ForEach(item.evidence.prefix(4)) { evidence in
                HStack(alignment: .top, spacing: 8) {
                    Text(evidence.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 60, alignment: .leading)
                    Text(evidence.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func workbenchHeader(_ item: ReviewItem, originalItem: TrackableItem, report: AlignmentReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    kindBadge(item.targetKind)
                    StatusBadge(text: originalItem.status.label, color: originalItem.status.color)
                    Spacer()
                    Text("#\(currentIndex + 1)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(item.targetTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)

                Text(report.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let firstFile = report.relatedFiles.first {
                    HStack(spacing: 8) {
                        Button {
                            store.openFile(firstFile)
                        } label: {
                            Label("打开首个证据", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            copyRedoPrompt(originalItem, report: report)
                        } label: {
                            Label("复制重做指令", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func alignmentSection(_ report: AlignmentReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "需求对齐", subtitle: report.requirementTitle == nil ? "未关联" : "已关联")

                VStack(alignment: .leading, spacing: 8) {
                    alignmentRow("业务需求", report.requirementTitle ?? "未找到直接关联的业务需求")
                    alignmentRow("业务价值", report.requirementValue ?? "未填写")
                }

                if report.acceptanceCriteria.isEmpty {
                    Text("未填写验收标准")
                        .font(.caption)
                        .foregroundStyle(VibeTheme.amber)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("验收标准")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(report.acceptanceCriteria, id: \.self) { criterion in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checklist")
                                    .font(.caption2)
                                    .foregroundStyle(VibeTheme.green)
                                    .frame(width: 14)
                                Text(criterion)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func alignmentRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func implementationEvidenceSection(_ report: AlignmentReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "实现证据", subtitle: "\(report.relatedFiles.count) 个文件线索")

                evidenceGroup("页面", report.matchedPages, icon: "rectangle.on.rectangle", color: VibeTheme.accent)
                evidenceGroup("API", report.matchedApis, icon: "point.3.connected.trianglepath.dotted", color: VibeTheme.green)
                evidenceGroup("数据库", report.matchedTables, icon: "cylinder", color: VibeTheme.amber)

                if !report.relatedFiles.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("相关文件")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(report.relatedFiles.prefix(6), id: \.self) { file in
                            Button {
                                store.openFile(file)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                    Text(file)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func evidenceGroup(_ title: String, _ evidence: [AlignmentEvidence], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text("\(title) (\(evidence.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if evidence.isEmpty {
                Text("未找到\(title)线索")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(evidence) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption.weight(.medium))
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func gapsAndRisksSection(_ report: AlignmentReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "缺失与风险")

                signalList("缺失", report.missingSignals, color: VibeTheme.amber)
                signalList("风险", report.riskSignals, color: VibeTheme.red)
            }
        }
    }

    private func signalList(_ title: String, _ signals: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(signals.isEmpty ? Color.secondary.opacity(0.4) : color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if signals.isEmpty {
                Text("暂无\(title)线索")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(signals, id: \.self) { signal in
                    Text("- \(signal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("验收备注")
                .font(.subheadline.weight(.medium))
            TextEditor(text: $notes)
                .frame(minHeight: 82)
                .padding(8)
                .background(Color(red: 0.08, green: 0.08, blue: 0.09))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1))
                )
        }
    }

    private func actionBar(originalItem: TrackableItem, report: AlignmentReport) -> some View {
        HStack(spacing: 12) {
            Button {
                skipItem()
            } label: {
                Label("跳过", systemImage: "forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                copyRedoPrompt(originalItem, report: report)
                rejectItem()
            } label: {
                Label("需重做", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(VibeTheme.red)

            Button {
                acceptItem()
            } label: {
                Label("通过", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeTheme.green)
        }
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(VibeTheme.green)

            Text("验收完成")
                .font(.title.weight(.semibold))

            Text("已处理 \(displaySession.items.count) 项")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 统计
            HStack(spacing: 24) {
                completionStat("通过", displaySession.items.filter { $0.decision == .confirmed }.count, VibeTheme.green)
                completionStat("重做", displaySession.items.filter { $0.decision == .redo }.count, VibeTheme.red)
                completionStat("跳过", displaySession.items.filter { $0.decision == .protected }.count, .secondary)
            }
            .padding(.vertical, 16)

            Button {
                onComplete()
            } label: {
                Text("完成验收")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    private func completionStat(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private var currentSessionItem: ReviewItem? {
        guard currentIndex < displaySession.items.count else { return nil }
        return displaySession.items[currentIndex]
    }

    private func findOriginalItem(_ id: String) -> TrackableItem? {
        let progress = ProgressDeriver.derive(from: store.data)
        return (progress.pages + progress.features).first { $0.id == id }
    }

    private func acceptItem() {
        var state = store.data.controlState
        ReviewService.reviewItem(in: &state, itemId: session.items[currentIndex].id, decision: .confirmed, notes: notes.isEmpty ? nil : notes)
        store.saveControlState(state)
        notes = ""
        advanceToNext()
    }

    private func rejectItem() {
        var state = store.data.controlState
        ReviewService.reviewItem(in: &state, itemId: session.items[currentIndex].id, decision: .redo, notes: notes.isEmpty ? nil : notes)
        store.saveControlState(state)
        notes = ""
        advanceToNext()
    }

    private func skipItem() {
        var state = store.data.controlState
        ReviewService.reviewItem(in: &state, itemId: session.items[currentIndex].id, decision: .protected, notes: notes.isEmpty ? nil : notes)
        store.saveControlState(state)
        notes = ""
        advanceToNext()
    }

    private func advanceToNext() {
        currentIndex += 1
    }

    private func copyRedoPrompt(_ item: TrackableItem, report: AlignmentReport) {
        store.copyRedoPrompt(for: item, notes: notes.isEmpty ? nil : notes)
    }
}

// MARK: - 变更对比视图

struct DiffReportView: View {
    let diff: DiffReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 摘要
            HStack(spacing: 16) {
                diffStat("新增", diff.added.count, VibeTheme.green, "plus.circle.fill")
                diffStat("修改", diff.modified.count, VibeTheme.amber, "pencil.circle.fill")
                diffStat("删除", diff.deleted.count, VibeTheme.red, "minus.circle.fill")
                diffStat("未变", diff.unchanged.count, .secondary, "checkmark.circle")
            }

            if diff.hasChanges {
                Divider()

                // 变更列表
                if !diff.added.isEmpty {
                    changeSection("新增", diff.added, VibeTheme.green, "plus.circle")
                }

                if !diff.modified.isEmpty {
                    changeSection("修改", diff.modified, VibeTheme.amber, "pencil.circle")
                }

                if !diff.deleted.isEmpty {
                    changeSection("删除", diff.deleted, VibeTheme.red, "minus.circle")
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 32))
                        .foregroundStyle(VibeTheme.green)
                    Text("自上次验收后无变更")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }

    private func diffStat(_ title: String, _ count: Int, _ color: Color, _ icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(count)")
                    .font(.title2.weight(.bold))
            }
            .foregroundStyle(count > 0 ? color : .secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func changeSection(_ title: String, _ items: [TrackableItem], _ color: Color, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text("\(title) (\(items.count))")
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(items.prefix(5)) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text(item.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(item.kind)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if items.count > 5 {
                Text("还有 \(items.count - 5) 项...")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - 时间线视图

struct TimelineView: View {
    let events: [TimelineEvent]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(events) { event in
                    timelineRow(event)
                }
            }
            .padding(16)
        }
    }

    private func timelineRow(_ event: TimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间线指示器
            VStack(spacing: 0) {
                Circle()
                    .fill(event.kind.color)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: event.kind.symbol)
                        .font(.caption)
                        .foregroundStyle(event.kind.color)
                    Text(event.title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(event.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !event.details.isEmpty {
                    Text(event.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - 生成记录行组件

struct GenerationRecordRowComponent: View {
    let record: GenerationRecord

    private var visibleFileCount: Int {
        record.generatedFiles.filter {
            !$0.hasPrefix("page:")
                && !$0.hasPrefix("api:")
                && !$0.hasPrefix("database:")
                && !$0.hasPrefix("component:")
                && !$0.hasPrefix("flow:")
        }.count
    }

    var body: some View {
        Card {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: record.kind.symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(VibeTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(VibeTheme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Spacer()

                        StatusBadge(text: record.status.label, color: record.status.color)
                    }

                    Text(record.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack {
                        Text(record.kind.label)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(record.timeAgo)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if visibleFileCount > 0 {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(visibleFileCount) 文件")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}
