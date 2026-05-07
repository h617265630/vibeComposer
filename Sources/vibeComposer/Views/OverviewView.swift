import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: ProjectStore
    let data: ActivityData
    let progress: ProjectProgress

    @State private var showingDiffDetail = false

    // 计算属性
    private var currentDiff: DiffReport {
        DiffTracker.computeDiff(since: data.controlState.baseline, current: data)
    }

    private var itemsNeedingReview: [TrackableItem] {
        ReviewService.itemsNeedingReview(from: data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 顶部状态卡片
                heroSection

                // 指标卡片
                metricsSection

                // 主要内容区
                HStack(alignment: .top, spacing: 16) {
                    // 左侧
                    VStack(alignment: .leading, spacing: 16) {
                        // 变更对比
                        diffSection

                        // 工作流
                        workflowSection
                    }
                    .frame(maxWidth: .infinity)

                    // 右侧
                    VStack(alignment: .leading, spacing: 16) {
                        // 验收队列
                        reviewQueueSection

                        // 问题操作
                        issuesSection

                        // Harness 状态
                        harnessSection
                    }
                    .frame(width: 380)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingDiffDetail) {
            DiffDetailSheet(diff: currentDiff)
        }
    }

    // MARK: - 顶部状态卡片

    private var heroSection: some View {
        Card {
            HStack(alignment: .top, spacing: 20) {
                // 左侧：状态信息
                VStack(alignment: .leading, spacing: 10) {
                    // 健康状态
                    HStack(spacing: 8) {
                        Circle()
                            .fill(healthColor)
                            .frame(width: 10, height: 10)
                        Text(progress.healthLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(healthColor)
                    }

                    // 标题
                    Text(progress.headline)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .lineLimit(2)

                    // 下一步
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                        Text(progress.nextStep)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // 右侧：统计数字
                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 16) {
                        statCircle("完成", progress.doneCount, VibeTheme.green)
                        statCircle("待验收", progress.reviewCount, VibeTheme.amber)
                        statCircle("风险", progress.riskCount, VibeTheme.red)
                    }

                    // 快速操作
                    if !itemsNeedingReview.isEmpty {
                        Button {
                            store.selectedTab = .control
                        } label: {
                            Label("开始验收 (\(itemsNeedingReview.count))", systemImage: "checkmark.shield")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(VibeTheme.green)
                    }
                }
            }
        }
    }

    private func statCircle(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60)
    }

    private var healthColor: Color {
        if progress.riskCount > 0 { return VibeTheme.red }
        if progress.reviewCount > 0 { return VibeTheme.amber }
        return VibeTheme.green
    }

    // MARK: - 指标卡片

    private var metricsSection: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "今日提交",
                value: "\(data.todayStats.commits)",
                detail: "\(data.todayStats.filesChanged) 文件",
                subtitle: "+\(data.todayStats.insertions) -\(data.todayStats.deletions)",
                symbol: "arrow.triangle.branch",
                color: VibeTheme.accent
            )

            metricCard(
                title: "页面",
                value: "\(data.frontendPages.count)",
                detail: "\(data.frontendScan.totalComponents) 组件",
                subtitle: "\(data.frontendScan.totalHooks) hooks",
                symbol: "rectangle.on.rectangle",
                color: VibeTheme.accent
            )

            metricCard(
                title: "API",
                value: "\(data.backendApis.count)",
                detail: "\(data.backendFlows.count) 流程",
                subtitle: "\(data.databaseTables.count) 表",
                symbol: "point.3.connected.trianglepath.dotted",
                color: VibeTheme.accent
            )

            metricCard(
                title: "规则偏移",
                value: "\(data.vibeRuleChecks.checks.count)",
                detail: "\(data.vibeRuleChecks.errors) 错误",
                subtitle: "\(data.vibeRuleChecks.warnings) 警告",
                symbol: "checklist.checked",
                color: data.vibeRuleChecks.errors > 0 ? VibeTheme.red : VibeTheme.amber
            )
        }
    }

    private func metricCard(title: String, value: String, detail: String, subtitle: String, symbol: String, color: Color) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    HStack(spacing: 4) {
                        Text(detail)
                            .font(.caption2)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(subtitle)
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 变更对比区域

    private var diffSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                // 标题
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("变更追踪")
                            .font(.headline)
                        Text(currentDiff.detailedSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if currentDiff.hasChanges {
                        Button {
                            showingDiffDetail = true
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                // 变更统计
                if currentDiff.hasChanges {
                    HStack(spacing: 12) {
                        changeIndicator("新增", currentDiff.added.count, VibeTheme.green, "plus.circle.fill")
                        changeIndicator("修改", currentDiff.modified.count, VibeTheme.amber, "pencil.circle.fill")
                        changeIndicator("删除", currentDiff.deleted.count, VibeTheme.red, "minus.circle.fill")
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(VibeTheme.green)
                        Text("自上次验收后无变更")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func changeIndicator(_ title: String, _ count: Int, _ color: Color, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 工作流区域

    private var workflowSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: data.vibeWorkflow.title, subtitle: data.vibeWorkflow.currentTask)

                if data.vibeWorkflow.steps.isEmpty {
                    Text("暂无 workflow.md 配置")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(data.vibeWorkflow.steps.prefix(6)) { step in
                        workflowStepRow(step)
                    }

                    if data.vibeWorkflow.steps.count > 6 {
                        Text("还有 \(data.vibeWorkflow.steps.count - 6) 个步骤...")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func workflowStepRow(_ step: VibeWorkflowStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // 状态指示器
            ZStack {
                Circle()
                    .stroke(step.status.color, lineWidth: 2)
                    .frame(width: 20, height: 20)

                if step.status == .done {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(step.status.color)
                } else if step.status == .active {
                    Circle()
                        .fill(step.status.color)
                        .frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(step.title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    StatusBadge(text: step.status.label, color: step.status.color)
                }
                Text(step.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - 验收队列区域

    private var reviewQueueSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("验收队列")
                            .font(.headline)
                        Text("确认完成会写入 .vibe-tracking.json")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if !itemsNeedingReview.isEmpty {
                        Button {
                            store.selectedTab = .control
                        } label: {
                            Label("验收", systemImage: "checkmark.shield")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(VibeTheme.green)
                    }
                }

                if itemsNeedingReview.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(VibeTheme.green)
                        Text("当前没有待验收项")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(itemsNeedingReview.prefix(5)) { item in
                        reviewQueueRow(item)
                    }

                    if itemsNeedingReview.count > 5 {
                        Text("还有 \(itemsNeedingReview.count - 5) 项待验收")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func reviewQueueRow(_ item: TrackableItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(item.status.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(item.businessMeaning)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            StatusBadge(text: item.status.label, color: item.status.color)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 问题区域

    private var issuesSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "问题操作", subtitle: "安全修复与下一步")

                if data.vibeRuleChecks.checks.isEmpty && data.codeQuality.checks.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(VibeTheme.green)
                        Text("当前没有可操作问题")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(data.vibeRuleChecks.checks.prefix(3)) { check in
                        RuleIssueRow(check: check)
                    }

                    ForEach(data.codeQuality.checks.prefix(max(0, 3 - data.vibeRuleChecks.checks.count))) { check in
                        QualityIssueRow(check: check)
                    }
                }
            }
        }
    }

    // MARK: - Harness 区域

    private var harnessSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Vibe Harness")
                        .font(.headline)
                    Spacer()
                    StatusBadge(text: data.vibeHarness.isComplete ? "完整" : "缺失", color: data.vibeHarness.isComplete ? VibeTheme.green : VibeTheme.amber)
                }

                if data.vibeHarness.isComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(VibeTheme.green)
                        Text("track / rules / workflow 已就绪")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("缺少 \(data.vibeHarness.missingFiles.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(data.vibeInventory.projectName)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
