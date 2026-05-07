import SwiftUI

// MARK: - 轮次历史视图

struct RoundsHistoryView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var selectedRound: VibeRound?
    @State private var showingStartRoundSheet = false
    @State private var navigateToControl = false

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            Divider()

            // 内容
            HStack(spacing: 0) {
                // 左侧：轮次列表
                roundsList
                    .frame(width: 300)

                Divider()

                // 右侧：轮次详情
                if let round = selectedRound {
                    roundDetail(round: round)
                } else if let currentRound = store.data.controlState.currentRound {
                    roundDetail(round: currentRound)
                } else {
                    emptySelection
                }
            }
        }
        .sheet(isPresented: $showingStartRoundSheet) {
            StartRoundSheet()
        }
        .onChange(of: navigateToControl) { _, newValue in
            if newValue {
                // 使用通知或其他方式切换 Tab
                navigateToControl = false
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Vibe 轮次历史")
                .font(.headline)

            Spacer()

            // 统计
            let stats = RoundService.roundStats(rounds: store.data.controlState.rounds)
            HStack(spacing: 16) {
                statChip("轮次", "\(stats.totalRounds)", VibeTheme.accent)
                statChip("Prompts", "\(stats.totalPrompts)", VibeTheme.amber)
                statChip("通过", "\(stats.totalAccepted)", VibeTheme.green)
            }

            Divider()
                .frame(height: 20)

            Button {
                showingStartRoundSheet = true
            } label: {
                Label("开始新轮次", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
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

    private var roundsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // 当前轮次
                if let currentRound = store.data.controlState.currentRound {
                    RoundRow(round: currentRound, isCurrent: true, isSelected: false)
                        .onTapGesture {
                            selectedRound = nil // 显示当前轮次
                        }
                }

                // 历史轮次
                ForEach(store.data.controlState.rounds) { round in
                    RoundRow(round: round, isCurrent: false, isSelected: selectedRound?.id == round.id)
                        .onTapGesture {
                            selectedRound = round
                        }
                }

                if store.data.controlState.rounds.isEmpty && store.data.controlState.currentRound == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("还没有开始任何轮次")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            showingStartRoundSheet = true
                        } label: {
                            Label("开始第一个轮次", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
        }
    }

    private func roundDetail(round: VibeRound) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 轮次信息
                roundInfoSection(round)

                // 目标
                if !round.goal.isEmpty {
                    goalSection(round)
                }

                // Prompt 记录
                if !round.prompts.isEmpty {
                    promptsSection(round)
                }

                // 验收结果
                resultsSection(round)

                // 操作按钮
                if round.status == .active {
                    activeRoundActions(round)
                }
            }
            .padding(20)
        }
    }

    private func roundInfoSection(_ round: VibeRound) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(round.title)
                    .font(.title3.weight(.semibold))
                Spacer()
                StatusBadge(text: round.status.label, color: round.status == .active ? VibeTheme.accent : VibeTheme.green)
            }

            HStack(spacing: 16) {
                Label(VibeDateFormatter.display.string(from: round.startedAt), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let endedAt = round.endedAt {
                    Label(VibeDateFormatter.display.string(from: endedAt), systemImage: "flag.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label("\(round.promptCount) 个 Prompt", systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func goalSection(_ round: VibeRound) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本轮目标")
                .font(.subheadline.weight(.semibold))
            Text(round.goal)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func promptsSection(_ round: VibeRound) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt 记录")
                .font(.subheadline.weight(.semibold))

            ForEach(round.prompts) { prompt in
                PromptRecordCard(prompt: prompt)
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func resultsSection(_ round: VibeRound) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("验收结果")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 20) {
                resultStat("通过", round.acceptedItemIDs.count, VibeTheme.green)
                resultStat("重做", round.redoItemIDs.count, VibeTheme.red)
                resultStat("生成", round.startGenerationCount, VibeTheme.accent)
            }

            if !round.acceptedItemIDs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("已通过项")
                        .font(.caption.weight(.medium))
                    ForEach(round.acceptedItemIDs.prefix(5), id: \.self) { id in
                        Text(id)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !round.redoItemIDs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("需重做项")
                        .font(.caption.weight(.medium))
                    ForEach(round.redoItemIDs.prefix(5), id: \.self) { id in
                        Text(id)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func resultStat(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func activeRoundActions(_ round: VibeRound) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前轮次操作")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                Button {
                    endCurrentRound()
                } label: {
                    Label("结束本轮", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VibeTheme.green)

                Button {
                    // 结束当前轮次
                    endCurrentRound()
                } label: {
                    Label("开始验收", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var emptySelection: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("选择左侧的轮次查看详情")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func endCurrentRound() {
        var state = store.data.controlState
        RoundService.endRound(in: &state)
        store.saveControlState(state)
        selectedRound = nil
    }
}

// MARK: - 轮次行

struct RoundRow: View {
    let round: VibeRound
    let isCurrent: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isCurrent ? VibeTheme.accent : VibeTheme.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(round.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    if isCurrent {
                        Text("当前")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(VibeTheme.accent)
                    }
                }
                Text("\(round.promptCount) prompts · \(round.acceptedItemIDs.count) 通过")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(VibeDateFormatter.timeAgo(from: round.startedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(isSelected ? VibeTheme.accent.opacity(0.1) : (isCurrent ? VibeTheme.accent.opacity(0.05) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Prompt 记录卡片

struct PromptRecordCard: View {
    let prompt: VibePromptRecord
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(VibeTheme.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt.source)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(prompt.model)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(VibeDateFormatter.timeAgo(from: prompt.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color(red: 0.94, green: 0.94, blue: 0.95))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt:")
                        .font(.caption.weight(.semibold))
                    Text(prompt.prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.92, green: 0.92, blue: 0.93))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    if !prompt.responseSummary.isEmpty {
                        Text("响应摘要:")
                            .font(.caption.weight(.semibold))
                        Text(prompt.responseSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.92, green: 0.92, blue: 0.93))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(10)
                .background(Color(red: 0.94, green: 0.94, blue: 0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - 开始轮次 Sheet

struct StartRoundSheet: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var goal = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("开始新的 Vibe 轮次")
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
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // 轮次标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("轮次标题")
                        .font(.subheadline.weight(.medium))
                    TextField("例如：实现用户登录功能", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // 目标
                VStack(alignment: .leading, spacing: 8) {
                    Text("本轮目标")
                        .font(.subheadline.weight(.medium))
                    TextField("描述本轮希望完成什么", text: $goal, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                // 提示
                VStack(alignment: .leading, spacing: 8) {
                    Text("提示")
                        .font(.subheadline.weight(.medium))
                    Text("开始轮次后，你可以：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• 记录每次给 LLM 的 prompt 和响应")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• 追踪本轮生成了哪些内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• 验收本轮的实现成果")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(red: 0.94, green: 0.94, blue: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)

            Divider()

            // 底部按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    startRound()
                } label: {
                    Text("开始轮次")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        }
        .frame(width: 450, height: 400)
    }

    private func startRound() {
        var state = store.data.controlState
        _ = RoundService.startRound(
            in: &state,
            title: title,
            goal: goal.isEmpty ? state.goal : goal
        )
        store.saveControlState(state)
        dismiss()
    }
}