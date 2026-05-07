import SwiftUI

// MARK: - 需求对齐分析视图

struct AlignmentAnalysisView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var selectedRequirement: ProjectRequirement?

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            Divider()

            // 内容
            HStack(spacing: 0) {
                // 左侧：需求列表
                requirementsList
                    .frame(width: 280)

                Divider()

                // 右侧：对齐分析
                if let requirement = selectedRequirement {
                    alignmentDetail(requirement: requirement)
                } else {
                    emptySelection
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("需求-实现对齐分析")
                .font(.headline)

            Spacer()

            // 统计
            let reports = AlignmentService.analyzeAllRequirements(data: store.data)
            let withEvidence = reports.filter { $0.hasImplementationEvidence }.count
            let total = reports.count

            HStack(spacing: 16) {
                statChip("需求", "\(total)", VibeTheme.accent)
                statChip("有实现", "\(withEvidence)", withEvidence > 0 ? VibeTheme.green : .secondary)
                statChip("无实现", "\(total - withEvidence)", total - withEvidence > 0 ? VibeTheme.red : .secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }

    private func statChip(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var requirementsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(store.data.controlState.requirements) { requirement in
                    RequirementRow(
                        requirement: requirement,
                        isSelected: selectedRequirement?.id == requirement.id
                    )
                    .onTapGesture {
                        selectedRequirement = requirement
                    }
                }

                if store.data.controlState.requirements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("还没有登记需求")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("在控制页面添加需求后，这里会显示对齐分析")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
        }
    }

    private func alignmentDetail(requirement: ProjectRequirement) -> some View {
        let report = AlignmentService.analyzeAlignment(requirement: requirement, data: store.data)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 需求信息
                requirementInfo(requirement)

                // 匹配度概览
                matchOverview(report: report)

                // 实现线索
                implementationEvidence(report: report)

                // 缺失和风险
                if !report.missingSignals.isEmpty || !report.riskSignals.isEmpty {
                    issuesSection(report: report)
                }

                // 验收标准
                if !requirement.acceptanceCriteria.isEmpty {
                    acceptanceCriteriaSection(requirement: requirement, report: report)
                }

                // AI 对齐 Prompt
                alignmentPromptSection(requirement: requirement, report: report)

                // 操作按钮
                actionButtons(requirement: requirement)
            }
            .padding(20)
        }
    }

    private func requirementInfo(_ requirement: ProjectRequirement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(requirement.title)
                    .font(.title3.weight(.semibold))
                Spacer()
                StatusBadge(text: requirement.status.label, color: statusColor(requirement.status))
            }

            if !requirement.userValue.isEmpty {
                Text(requirement.userValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(requirement.priority.label, systemImage: "flag")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if !requirement.acceptanceCriteria.isEmpty {
                    Label("\(requirement.acceptanceCriteria.count) 条验收标准", systemImage: "checklist")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func matchOverview(report: AlignmentReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("匹配度概览")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 16) {
                matchIndicator("页面", report.matchedPages.count, VibeTheme.accent)
                matchIndicator("API", report.matchedApis.count, VibeTheme.green)
                matchIndicator("数据库", report.matchedTables.count, VibeTheme.amber)
            }

            Text(report.recommendation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func matchIndicator(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(count > 0 ? color.opacity(0.1) : Color(red: 0.94, green: 0.94, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func implementationEvidence(report: AlignmentReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("实现线索")
                .font(.subheadline.weight(.semibold))

            if !report.hasImplementationEvidence {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(VibeTheme.amber)
                    Text("未找到实现线索")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // 页面线索
                if !report.matchedPages.isEmpty {
                    evidenceSection(title: "页面", items: report.matchedPages, color: VibeTheme.accent)
                }

                // API 线索
                if !report.matchedApis.isEmpty {
                    evidenceSection(title: "API", items: report.matchedApis, color: VibeTheme.green)
                }

                // 数据库线索
                if !report.matchedTables.isEmpty {
                    evidenceSection(title: "数据库", items: report.matchedTables, color: VibeTheme.amber)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func evidenceSection(title: String, items: [AlignmentEvidence], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption.weight(.medium))
            }

            ForEach(items) { item in
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.caption)
                    Spacer()
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let path = item.path {
                        Button {
                            store.openFile(path)
                        } label: {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    private func issuesSection(report: AlignmentReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !report.missingSignals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(VibeTheme.amber)
                        Text("缺失信号")
                            .font(.caption.weight(.medium))
                    }

                    ForEach(report.missingSignals, id: \.self) { signal in
                        Text("• \(signal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !report.riskSignals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.octagon")
                            .foregroundStyle(VibeTheme.red)
                        Text("风险信号")
                            .font(.caption.weight(.medium))
                    }

                    ForEach(report.riskSignals, id: \.self) { signal in
                        Text("• \(signal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func acceptanceCriteriaSection(requirement: ProjectRequirement, report: AlignmentReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("验收标准")
                .font(.subheadline.weight(.semibold))

            ForEach(requirement.acceptanceCriteria, id: \.self) { criteria in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(VibeTheme.green)
                    Text(criteria)
                        .font(.caption)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func alignmentPromptSection(requirement: ProjectRequirement, report: AlignmentReport) -> some View {
        let item = TrackableItem(
            id: "requirement:\(requirement.id)",
            title: requirement.title,
            kind: "feature",
            status: .needsReview,
            confidence: .medium,
            confidenceReason: "",
            businessMeaning: requirement.userValue,
            lastTouched: nil,
            evidence: []
        )
        let prompt = VibeRoundService.alignmentPrompt(for: item, report: report)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI 对齐分析 Prompt")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    copyToPasteboard(prompt)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(prompt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.94, green: 0.94, blue: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func actionButtons(requirement: ProjectRequirement) -> some View {
        HStack(spacing: 12) {
            Button {
                markAsDone(requirement)
            } label: {
                Label("标记完成", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeTheme.green)

            Button {
                markAsRedo(requirement)
            } label: {
                Label("需要重做", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(VibeTheme.red)
        }
    }

    private var emptySelection: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("选择左侧的需求查看对齐分析")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func statusColor(_ status: ProjectRequirementStatus) -> Color {
        switch status {
        case .done: VibeTheme.green
        case .inProgress: VibeTheme.accent
        case .needsReview: VibeTheme.amber
        case .planned: .secondary
        case .redo: VibeTheme.red
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func markAsDone(_ requirement: ProjectRequirement) {
        var state = store.data.controlState
        if let index = state.requirements.firstIndex(where: { $0.id == requirement.id }) {
            state.requirements[index].status = .done
            state.requirements[index].updatedAt = Date()
        }
        store.saveControlState(state)
    }

    private func markAsRedo(_ requirement: ProjectRequirement) {
        var state = store.data.controlState
        if let index = state.requirements.firstIndex(where: { $0.id == requirement.id }) {
            state.requirements[index].status = .redo
            state.requirements[index].updatedAt = Date()
        }
        store.saveControlState(state)
    }
}

// MARK: - 需求行

struct RequirementRow: View {
    let requirement: ProjectRequirement
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(requirement.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                Text(requirement.status.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(10)
        .background(isSelected ? VibeTheme.accent.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var statusColor: Color {
        switch requirement.status {
        case .done: VibeTheme.green
        case .inProgress: VibeTheme.accent
        case .needsReview: VibeTheme.amber
        case .planned: .secondary
        case .redo: VibeTheme.red
        }
    }
}
