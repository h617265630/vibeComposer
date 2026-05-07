import SwiftUI

struct ControlCenterView: View {
    @EnvironmentObject private var store: ProjectStore
    let progress: ProjectProgress

    @State private var draftGoal = ""
    @State private var newRequirement = ""
    @State private var newRequirementValue = ""
    @State private var newRequirementCriteria = ""
    @State private var roundTitle = ""
    @State private var promptDraft = ""
    @State private var responseSummaryDraft = ""
    @State private var promptModel = ""
    @State private var promptSource = ""
    @State private var previewBaseURLDraft = ""
    @State private var verificationCommandDraft = ""
    @State private var selectedTab = 0
    @State private var showingReviewSession = false
    @State private var showingDiffDetail = false

    // 计算属性
    private var itemsNeedingReview: [TrackableItem] {
        ReviewService.itemsNeedingReview(from: store.data)
    }

    private var currentDiff: DiffReport {
        DiffTracker.computeDiff(since: store.data.controlState.baseline, current: store.data)
    }

    private var reviewStats: ReviewStats {
        ReviewService.reviewStats(from: store.data.controlState)
    }

    private var baselineCount: Int {
        store.data.controlState.baseline?.itemFingerprints.count ?? 0
    }

    private var inspectionTargets: [InspectionTarget] {
        VibeRoundService.inspectionTargets(for: store.data, previewBaseURL: store.data.controlState.previewBaseURL)
    }

    private var verificationPlan: VerificationPlan {
        VibeRoundService.verificationPlan(for: store.data, customCommand: store.data.controlState.verificationCommand)
    }

    private var loopStageText: String {
        if !itemsNeedingReview.isEmpty {
            return "\(itemsNeedingReview.count) 项实现等待验收"
        }
        if store.data.controlState.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "等待本轮目标"
        }
        return "本轮暂时没有新的待验收实现"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 顶部操作栏
                topActionBar

                // 变更对比卡片
                diffCard

                // Tab 选择
                tabSelector

                // Tab 内容
                tabContent
            }
            .padding(18)
        }
        .sheet(isPresented: $showingReviewSession) {
            if let session = store.data.controlState.currentSession {
                ReviewSessionSheet(session: session)
            }
        }
        .sheet(isPresented: $showingDiffDetail) {
            DiffDetailSheet(diff: currentDiff)
        }
    }

    // MARK: - 顶部操作栏

    private var topActionBar: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("本轮 Vibe Loop")
                            .font(.headline)
                        Text(loopStageText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        loopMetric("需求", "\(store.data.controlState.requirements.count)", VibeTheme.accent)
                        loopMetric("待验收", "\(itemsNeedingReview.count)", itemsNeedingReview.isEmpty ? .secondary : VibeTheme.amber)
                        loopMetric("已固化", "\(baselineCount)", baselineCount > 0 ? VibeTheme.green : .secondary)
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundStyle(VibeTheme.accent)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前目标")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("描述你希望这个项目当前完成什么", text: $draftGoal, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .onAppear { draftGoal = store.data.controlState.goal }

                        HStack {
                            Button {
                                saveGoal()
                            } label: {
                                Label("保存", systemImage: "checkmark")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            if !itemsNeedingReview.isEmpty {
                                Button {
                                    startReviewSession()
                                } label: {
                                    Label("开始验收 (\(itemsNeedingReview.count))", systemImage: "checkmark.shield")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(VibeTheme.green)
                            }
                        }
                    }
                }
            }
        }
    }

    private func loopMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 58, alignment: .trailing)
    }

    // MARK: - 变更对比卡片

    private var diffCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自上次验收后的变更")
                            .font(.subheadline.weight(.semibold))
                        Text(currentDiff.detailedSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if currentDiff.hasChanges {
                        Button {
                            showingDiffDetail = true
                        } label: {
                            Text("查看详情")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // 变更统计条
                if currentDiff.hasChanges {
                    HStack(spacing: 8) {
                        if !currentDiff.added.isEmpty {
                            changeBar("新增", currentDiff.added.count, VibeTheme.green)
                        }
                        if !currentDiff.modified.isEmpty {
                            changeBar("修改", currentDiff.modified.count, VibeTheme.amber)
                        }
                        if !currentDiff.deleted.isEmpty {
                            changeBar("删除", currentDiff.deleted.count, VibeTheme.red)
                        }
                    }
                }
            }
        }
    }

    private func changeBar(_ title: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
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

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(0, "工作包", "shippingbox")
            tabButton(1, "需求管理", "list.bullet.rectangle")
            tabButton(2, "验收队列", "checkmark.shield")
            tabButton(3, "生成记录", "sparkles")
            tabButton(4, "时间线", "timeline.selection")
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func tabButton(_ index: Int, _ title: String, _ icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(selectedTab == index ? VibeTheme.accent.opacity(0.15) : Color.clear)
            .foregroundStyle(selectedTab == index ? VibeTheme.accent : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 内容

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            roundWorkspaceTab
        case 1:
            requirementsTab
        case 2:
            reviewQueueTab
        case 3:
            generationsTab
        case 4:
            timelineTab
        default:
            EmptyView()
        }
    }

    // MARK: - 工作包 Tab

    private var roundWorkspaceTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            roundSummaryCard
            roundSettingsCard
            promptCaptureCard
            inspectionTargetsCard
            alignmentAssistCard
            verificationPlanCard
            roundHistoryCard
        }
        .onAppear {
            roundTitle = store.data.controlState.currentRound?.title ?? store.data.controlState.goal
            previewBaseURLDraft = store.data.controlState.previewBaseURL
            verificationCommandDraft = store.data.controlState.verificationCommand
        }
    }

    private var roundSummaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.data.controlState.currentRound?.title ?? "还没有开始本轮工作包")
                            .font(.headline)
                        Text(store.data.controlState.currentRound?.goal.nonEmpty ?? store.data.controlState.goal.nonEmpty ?? "先写下本轮目标，再开始 vibe coding。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    StatusBadge(
                        text: store.data.controlState.currentRound?.status.label ?? "未开始",
                        color: store.data.controlState.currentRound == nil ? .secondary : VibeTheme.accent
                    )
                }

                HStack(spacing: 14) {
                    roundStat("Prompt", "\(store.data.controlState.currentRound?.prompts.count ?? 0)", VibeTheme.accent)
                    roundStat("生成记录", "\(store.data.controlState.generations.count)", VibeTheme.green)
                    roundStat("待验收", "\(itemsNeedingReview.count)", itemsNeedingReview.isEmpty ? .secondary : VibeTheme.amber)
                    roundStat("历史轮次", "\(store.data.controlState.rounds.count)", .secondary)
                }

                HStack(spacing: 8) {
                    TextField("本轮标题", text: $roundTitle)
                        .textFieldStyle(.roundedBorder)

                    if store.data.controlState.currentRound == nil {
                        Button {
                            store.startRound(title: roundTitle.nonEmpty ?? "本轮工作包")
                        } label: {
                            Label("开始", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            store.endCurrentRound()
                        } label: {
                            Label("结束", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(VibeTheme.green)
                    }
                }
            }
        }
    }

    private func roundStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var roundSettingsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "检查设置", subtitle: "用于页面预览、API 命令和后台验证")

                TextField("预览 Base URL，例如 http://localhost:3000", text: $previewBaseURLDraft)
                    .textFieldStyle(.roundedBorder)
                TextField("验证命令，例如 npm test / pnpm test / swift test", text: $verificationCommandDraft)
                    .textFieldStyle(.roundedBorder)

                Button {
                    store.saveRoundSettings(previewBaseURL: previewBaseURLDraft, verificationCommand: verificationCommandDraft)
                } label: {
                    Label("保存设置", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var promptCaptureCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "记录 LLM Prompt", subtitle: "把本轮真实 vibe 内容放进工作包")

                TextField("来源，例如 Cursor / ChatGPT / Claude Code", text: $promptSource)
                    .textFieldStyle(.roundedBorder)
                TextField("模型，例如 Claude / GPT / Gemini", text: $promptModel)
                    .textFieldStyle(.roundedBorder)
                TextField("本次发给 LLM 的 prompt", text: $promptDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                TextField("LLM 回复/实现摘要", text: $responseSummaryDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...6)

                Button {
                    store.addRoundPrompt(
                        prompt: promptDraft,
                        responseSummary: responseSummaryDraft,
                        model: promptModel,
                        source: promptSource
                    )
                    promptDraft = ""
                    responseSummaryDraft = ""
                } label: {
                    Label("记录 Prompt", systemImage: "text.bubble")
                }
                .buttonStyle(.borderedProminent)
                .disabled(promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let round = store.data.controlState.currentRound, !round.prompts.isEmpty {
                    Divider()
                    ForEach(round.prompts.prefix(3)) { prompt in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(prompt.prompt)
                                .font(.caption.weight(.medium))
                                .lineLimit(2)
                            Text("\(prompt.source) · \(prompt.model)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var inspectionTargetsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "肉眼检查目标", subtitle: "\(inspectionTargets.count) 项")

                if inspectionTargets.isEmpty {
                    Text("暂无页面/API/数据库检查目标。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(inspectionTargets.prefix(10)) { target in
                        HStack(spacing: 8) {
                            StatusBadge(text: target.kind.label, color: inspectionColor(target.kind))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.title)
                                    .font(.caption.weight(.medium))
                                Text(target.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                store.openInspectionTarget(target)
                            } label: {
                                Image(systemName: target.openURL == nil && target.path == nil ? "eye" : "arrow.up.right.square")
                            }
                            .buttonStyle(.borderless)
                            .disabled(target.openURL == nil && target.path == nil)

                            if target.command != nil {
                                Button {
                                    store.copyInspectionCommand(target)
                                } label: {
                                    Image(systemName: "terminal")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
    }

    private func inspectionColor(_ kind: InspectionTargetKind) -> Color {
        switch kind {
        case .page: VibeTheme.accent
        case .api: VibeTheme.green
        case .database: VibeTheme.amber
        case .file: .secondary
        }
    }

    private var alignmentAssistCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "AI 对齐辅助", subtitle: "复制给 LLM 做语义检查")

                if itemsNeedingReview.isEmpty {
                    Text("当前没有待验收项。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(itemsNeedingReview.prefix(6)) { item in
                        HStack(spacing: 8) {
                            StatusBadge(text: item.status.label, color: item.status.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Text(item.confidenceReason)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                store.copyAlignmentPrompt(for: item)
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var verificationPlanCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "后台验证计划", subtitle: "\(verificationPlan.checks.count) 项")
                    if !store.data.controlState.verificationCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            store.runVerificationCommand()
                        } label: {
                            Label("运行命令", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                ForEach(verificationPlan.checks) { check in
                    HStack(alignment: .top, spacing: 8) {
                        StatusBadge(text: check.kind.label, color: verificationColor(check.kind))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                                .font(.caption.weight(.medium))
                            Text(check.command ?? check.detail)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func verificationColor(_ kind: VerificationCheckKind) -> Color {
        switch kind {
        case .command: VibeTheme.accent
        case .test: VibeTheme.green
        case .manual: VibeTheme.amber
        case .api: VibeTheme.green
        case .database: VibeTheme.amber
        }
    }

    private var roundHistoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "轮次历史", subtitle: "\(store.data.controlState.rounds.count) 轮")

                if store.data.controlState.rounds.isEmpty {
                    Text("结束本轮后会出现在这里。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.data.controlState.rounds.prefix(5)) { round in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(round.title)
                                    .font(.caption.weight(.medium))
                                Text("\(round.prompts.count) prompt · 通过 \(round.acceptedItemIDs.count) · 重做 \(round.redoItemIDs.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            StatusBadge(text: round.status.label, color: VibeTheme.green)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 需求管理 Tab

    private var requirementsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 添加需求
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("添加需求")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        TextField("输入需求描述", text: $newRequirement)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            addRequirement()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                        .disabled(newRequirement.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    TextField("业务价值（可选）", text: $newRequirementValue, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    TextField("验收标准，每行一条（可选）", text: $newRequirementCriteria, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)
                }
            }

            // 需求列表
            if store.data.controlState.requirements.isEmpty {
                emptyState("还没有登记需求", "在上方输入框添加你的业务需求")
            } else {
                ForEach(store.data.controlState.requirements) { requirement in
                    RequirementCard(requirement: requirement)
                }
            }
        }
    }

    // MARK: - 验收队列 Tab

    private var reviewQueueTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 验收统计
            if reviewStats.totalSessions > 0 {
                Card {
                    HStack(spacing: 20) {
                        statItem("验收会话", "\(reviewStats.totalSessions)", VibeTheme.accent)
                        statItem("总项目数", "\(reviewStats.totalItems)", VibeTheme.accent)
                        statItem("通过率", String(format: "%.0f%%", reviewStats.acceptanceRate), reviewStats.acceptanceRate >= 80 ? VibeTheme.green : VibeTheme.amber)
                    }
                }
            }

            // 当前待验收
            if itemsNeedingReview.isEmpty {
                emptyState("当前没有待验收项", "继续 vibe coding，新的实现会自动加入验收队列")
            } else {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("待验收项目")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                startReviewSession()
                            } label: {
                                Label("开始验收", systemImage: "play.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        ForEach(itemsNeedingReview.prefix(8)) { item in
                            ReviewQueueItemRow(item: item)
                        }

                        if itemsNeedingReview.count > 8 {
                            Text("还有 \(itemsNeedingReview.count - 8) 项...")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 生成记录 Tab

    private var generationsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            let records = store.data.controlState.generations

            if records.isEmpty {
                emptyState("暂无生成记录", "LLM 生成的内容会自动记录在这里")
            } else {
                // 按类型分组
                let grouped = Dictionary(grouping: records, by: \.kind)

                ForEach(GenerationKind.allCases, id: \.self) { kind in
                    if let items = grouped[kind], !items.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: kind.symbol)
                                        .foregroundStyle(VibeTheme.accent)
                                    Text("\(kind.label) (\(items.count))")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }

                                ForEach(items.prefix(5)) { record in
                                    GenerationRecordCard(record: record)
                                }

                                if items.count > 5 {
                                    Text("还有 \(items.count - 5) 项...")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 时间线 Tab

    private var timelineTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            let events = store.data.controlState.timeline

            if events.isEmpty {
                emptyState("暂无时间线记录", "验收活动会记录在这里")
            } else {
                Card {
                    TimelineView(events: events)
                }
            }
        }
    }

    // MARK: - 辅助视图

    private func emptyState(_ title: String, _ detail: String) -> some View {
        Card {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private func statItem(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func saveGoal() {
        var state = store.data.controlState
        state.goal = draftGoal
        store.saveControlState(state)
    }

    private func addRequirement() {
        guard let title = newRequirement.trimmingCharacters(in: .whitespaces).nonEmpty else { return }
        var state = store.data.controlState
        state.requirements.append(ProjectRequirement(
            id: UUID().uuidString,
            title: title,
            userValue: newRequirementValue,
            acceptanceCriteria: newRequirementCriteria.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            priority: .medium,
            status: .planned,
            updatedAt: Date()
        ))
        newRequirement = ""
        newRequirementValue = ""
        newRequirementCriteria = ""
        store.saveControlState(state)
    }

    private func startReviewSession() {
        var state = store.data.controlState
        _ = ReviewService.startReviewSession(in: &state, items: itemsNeedingReview)
        store.saveControlState(state)
        showingReviewSession = true
    }
}

// MARK: - 辅助组件

struct RequirementCard: View {
    @EnvironmentObject private var store: ProjectStore
    let requirement: ProjectRequirement

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(requirement.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        if !requirement.userValue.isEmpty {
                            Text(requirement.userValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    StatusBadge(text: requirement.status.label, color: statusColor)
                }

                HStack(spacing: 8) {
                    Label(requirement.priority.label, systemImage: "flag")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if !requirement.acceptanceCriteria.isEmpty {
                        Label("\(requirement.acceptanceCriteria.count) 条验收标准", systemImage: "checklist")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(VibeDateFormatter.timeAgo(from: requirement.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
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

struct ReviewQueueItemRow: View {
    @EnvironmentObject private var store: ProjectStore
    let item: TrackableItem

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(item.status.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(item.kind)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            StatusBadge(text: item.status.label, color: item.status.color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sheet 视图

struct ReviewSessionSheet: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    let session: ReviewSession

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("验收会话")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(red: 0.06, green: 0.06, blue: 0.07))

            Divider()

            // 验收内容
            ReviewSessionView(session: session) {
                var state = store.data.controlState
                ReviewService.endReviewSession(in: &state)
                store.saveControlState(state)
                dismiss()
            }
        }
        .frame(width: 600, height: 700)
    }
}

struct DiffDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let diff: DiffReport

    private var sinceLabel: String {
        diff.since == Date.distantPast
            ? "尚未建立验收基线"
            : "自 \(VibeDateFormatter.display.string(from: diff.since)) 以来的变更"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("变更详情")
                        .font(.title2.weight(.semibold))
                    Text(sinceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(red: 0.06, green: 0.06, blue: 0.07))

            Divider()

            // 变更内容
            ScrollView {
                DiffReportView(diff: diff)
                    .padding(16)
            }
        }
        .frame(width: 600, height: 700)
    }
}
