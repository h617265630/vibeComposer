import SwiftUI

// MARK: - 生成记录主视图

struct GenerationRecordsView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var showingAddSheet = false
    @State private var showingImportSheet = false
    @State private var selectedKind: GenerationKind?
    @State private var filterStatus: GenerationStatus?
    @State private var claudeSessions: [ClaudeSession] = []
    @State private var isLoadingSessions = false

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            Divider()

            // 内容
            if store.data.controlState.generations.isEmpty {
                emptyState
            } else {
                recordsList
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddGenerationSheet()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportFromClaudeSheet(claudeSessions: claudeSessions)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("LLM 生成记录")
                .font(.headline)

            Spacer()

            // 筛选
            Menu {
                Button("全部") { filterStatus = nil }
                ForEach([GenerationStatus.pending, .reviewing, .accepted, .rejected], id: \.self) { status in
                    Button(status.label) { filterStatus = status }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text(filterStatus?.label ?? "筛选")
                }
                .font(.caption)
            }
            .menuStyle(.borderlessButton)

            // 从 Claude Code 导入
            Button {
                loadClaudeSessions()
            } label: {
                HStack(spacing: 4) {
                    if isLoadingSessions {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.down.doc")
                    }
                    Text("从 Claude Code 导入")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                showingAddSheet = true
            } label: {
                Label("手动记录", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("暂无生成记录")
                .font(.headline)

            Text("点击上方按钮，记录 LLM 生成的内容")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    loadClaudeSessions()
                } label: {
                    Label("从 Claude Code 导入", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingAddSheet = true
                } label: {
                    Label("手动记录", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func loadClaudeSessions() {
        guard let projectPath = store.projectURL?.path else { return }

        isLoadingSessions = true

        Task {
            let sessions = ClaudeCodeSessionService.readSessions(for: projectPath)
            await MainActor.run {
                self.claudeSessions = sessions
                self.isLoadingSessions = false

                if !sessions.isEmpty {
                    showingImportSheet = true
                }
            }
        }
    }

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let filtered = filterRecords(store.data.controlState.generations)

                ForEach(filtered) { record in
                    GenerationRecordCard(record: record)
                }
            }
            .padding(18)
        }
    }

    private func filterRecords(_ records: [GenerationRecord]) -> [GenerationRecord] {
        if let status = filterStatus {
            return records.filter { $0.status == status }
        }
        return records
    }
}

// MARK: - 生成记录卡片

struct GenerationRecordCard: View {
    @EnvironmentObject private var store: ProjectStore
    let record: GenerationRecord
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // 主行
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // 类型图标
                    Image(systemName: record.kind.symbol)
                        .font(.title2)
                        .foregroundStyle(VibeTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(VibeTheme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // 内容
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(record.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)

                            StatusBadge(text: record.status.label, color: record.status.color)
                        }

                        Text(record.kind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // 时间
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(record.timeAgo)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("\(record.generatedFiles.count) 文件")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            }
            .buttonStyle(.plain)

            // 展开内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // 描述
                    if !record.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("描述")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(record.description)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }

                    // 来源 Prompt
                    if let prompt = record.sourcePrompt, !prompt.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("来源 Prompt")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(prompt)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(red: 0.94, green: 0.94, blue: 0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // 生成的文件
                    if !record.generatedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("生成的文件")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(record.generatedFiles, id: \.self) { file in
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(file)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        store.openFile(file)
                                    } label: {
                                        Image(systemName: "arrow.right.circle")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }

                    // 操作按钮
                    HStack(spacing: 12) {
                        if record.status == .pending {
                            Button {
                                updateStatus(.reviewing)
                            } label: {
                                Label("开始检查", systemImage: "eye")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if record.status == .reviewing {
                            Button {
                                updateStatus(.accepted)
                            } label: {
                                Label("通过", systemImage: "checkmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(VibeTheme.green)

                            Button {
                                updateStatus(.rejected)
                            } label: {
                                Label("拒绝", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(VibeTheme.red)
                        }

                        Spacer()

                        if let notes = record.reviewNotes, !notes.isEmpty {
                            Text("备注: \(notes)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(14)
                .background(Color(red: 0.94, green: 0.94, blue: 0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2))
        )
    }

    private func updateStatus(_ status: GenerationStatus) {
        var state = store.data.controlState
        var gens = state.generations
        GenerationRecordService.updateStatus(&gens, id: record.id, status: status)
        state.generations = gens
        store.saveControlState(state)
    }
}

// MARK: - 添加生成记录 Sheet

struct AddGenerationSheet: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: GenerationKind = .page
    @State private var title = ""
    @State private var description = ""
    @State private var prompt = ""
    @State private var responseSummary = ""
    @State private var filesText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("记录 LLM 生成内容")
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 类型选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("生成类型")
                            .font(.subheadline.weight(.medium))
                        Picker("", selection: $kind) {
                            ForEach(GenerationKind.allCases, id: \.self) { k in
                                Text(k.label).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 标题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标题")
                            .font(.subheadline.weight(.medium))
                        TextField("例如：登录页面", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("描述")
                            .font(.subheadline.weight(.medium))
                        TextField("简要描述生成的内容", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    // 来源 Prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("来源 Prompt（可选）")
                            .font(.subheadline.weight(.medium))
                        TextEditor(text: $prompt)
                            .frame(height: 80)
                            .padding(4)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2))
                            )
                    }

                    // 响应摘要
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LLM 响应摘要（可选）")
                            .font(.subheadline.weight(.medium))
                        TextEditor(text: $responseSummary)
                            .frame(height: 60)
                            .padding(4)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2))
                            )
                    }

                    // 生成的文件
                    VStack(alignment: .leading, spacing: 8) {
                        Text("生成的文件路径（每行一个）")
                            .font(.subheadline.weight(.medium))
                        TextEditor(text: $filesText)
                            .frame(height: 80)
                            .padding(4)
                            .font(.caption.monospaced())
                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2))
                            )
                    }
                }
                .padding(16)
            }

            Divider()

            // 底部按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    save()
                } label: {
                    Text("保存记录")
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        }
        .frame(width: 500, height: 600)
    }

    private func save() {
        let files = filesText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let record = GenerationRecordService.createManualRecord(
            kind: kind,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            files: files,
            prompt: prompt.trimmingCharacters(in: .whitespaces).isEmpty ? nil : prompt,
            responseSummary: responseSummary.trimmingCharacters(in: .whitespaces).isEmpty ? nil : responseSummary
        )

        var state = store.data.controlState
        state.addGeneration(record)
        store.saveControlState(state)

        dismiss()
    }
}

// MARK: - 从 Claude Code 导入 Sheet

struct ImportFromClaudeSheet: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    let claudeSessions: [ClaudeSession]
    @State private var selectedSessions: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("从 Claude Code 导入")
                        .font(.title2.weight(.semibold))
                    Text("发现 \(claudeSessions.count) 个会话，选择要导入的记录")
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
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))

            Divider()

            // 会话列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(claudeSessions) { session in
                        ClaudeSessionRow(
                            session: session,
                            isSelected: selectedSessions.contains(session.id)
                        ) {
                            if selectedSessions.contains(session.id) {
                                selectedSessions.remove(session.id)
                            } else {
                                selectedSessions.insert(session.id)
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // 底部按钮
            HStack {
                Button("全选") {
                    if selectedSessions.count == claudeSessions.count {
                        selectedSessions.removeAll()
                    } else {
                        selectedSessions = Set(claudeSessions.map { $0.id })
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("已选择 \(selectedSessions.count) 个会话")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    importSelected()
                } label: {
                    Text("导入选中")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSessions.isEmpty)
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        }
        .frame(width: 600, height: 500)
    }

    private func importSelected() {
        guard let projectPath = store.projectURL?.path else { return }

        let sessionsToImport = claudeSessions.filter { selectedSessions.contains($0.id) }
        let records = ClaudeCodeSessionService.toGenerationRecords(
            sessions: sessionsToImport,
            projectPath: projectPath
        )

        var state = store.data.controlState
        for record in records {
            state.addGeneration(record)
        }
        store.saveControlState(state)

        dismiss()
    }
}

struct ClaudeSessionRow: View {
    let session: ClaudeSession
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 选中指示
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? VibeTheme.accent : .secondary)

                // 内容
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(session.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Spacer()

                        Text(VibeDateFormatter.timeAgo(from: session.lastActivity))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 12) {
                        Label("\(session.stats.filesWritten + session.stats.filesEdited) 文件", systemImage: "doc")
                        Label("\(session.stats.toolCalls) 操作", systemImage: "terminal")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(isSelected ? VibeTheme.accent.opacity(0.08) : Color(red: 0.96, green: 0.96, blue: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? VibeTheme.accent : Color.gray.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }
}
