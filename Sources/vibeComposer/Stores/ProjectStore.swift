import AppKit
import Combine
import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    @Published var projectURL: URL?
    @Published var data: ActivityData = .empty
    @Published var selectedTab: AppTab = .control
    @Published var isLoading = false
    @Published var statusMessage = "选择一个项目文件夹开始"
    @Published var errorMessage: String?

    private let tracker = FileSnapshotTracker()
    private var refreshTimer: Timer?

    init() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "lastProjectBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], bookmarkDataIsStale: &stale), !stale {
                projectURL = url
                refresh()
            }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(force: false) }
        }
    }

    func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            projectURL = url
            tracker.reset()
            if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: "lastProjectBookmark")
            }
            refresh()
        }
    }

    func refresh(force: Bool = true) {
        guard let projectURL else {
            data = .empty
            statusMessage = "选择一个项目文件夹开始"
            return
        }

        if isLoading {
            return
        }

        let root = projectURL
        let changes = tracker.detectChanges(root: root)
        let hasExistingScan = !data.vibeInventory.projectName.isEmpty || !data.projectStructure.isEmpty

        guard RefreshPolicy.shouldRunFullScan(force: force, hasChanges: !changes.isEmpty, hasExistingScan: hasExistingScan) else {
            statusMessage = "未检测到变化 · \(VibeDateFormatter.display.string(from: Date()))"
            return
        }

        isLoading = true
        errorMessage = nil
        let control = Self.loadControlState(root: root)
        Task { [weak self] in
            var scanned = ProjectScanner.scan(root: root, recentChanges: changes, controlState: control)
            let syncedControl = ReviewService.controlStateAfterScan(scanned, previousState: control)
            if syncedControl != control {
                do {
                    try Self.writeControlState(syncedControl, root: root)
                } catch {
                    self?.errorMessage = "保存生成记录失败：\(error.localizedDescription)"
                }
            }
            scanned.controlState = syncedControl
            self?.data = scanned
            self?.isLoading = false
            self?.statusMessage = "已扫描 \(root.lastPathComponent) · \(VibeDateFormatter.display.string(from: Date()))"
        }
    }

    func generateHarness() {
        guard let projectURL else { return }
        do {
            try HarnessService.generate(root: projectURL, activity: data)
            statusMessage = ".vibe harness 已生成"
            refresh()
        } catch {
            errorMessage = "生成 .vibe harness 失败：\(error.localizedDescription)"
        }
    }

    func repairTrackRegistration(for check: VibeRuleCheck) {
        guard let projectURL else { return }
        do {
            if try HarnessService.repairTrackRegistration(root: projectURL, for: check) {
                statusMessage = "已添加到 .vibe/track.md：\(check.target)"
                refresh()
            } else {
                statusMessage = "这个问题不适合自动修复，已保留为手动处理"
            }
        } catch {
            errorMessage = "修复 track.md 失败：\(error.localizedDescription)"
        }
    }

    func openTrackFile() {
        guard let projectURL else { return }
        NSWorkspace.shared.open(projectURL.child(".vibe/track.md"))
    }

    func openVibeFolder() {
        guard let projectURL else { return }
        NSWorkspace.shared.open(projectURL.child(".vibe"))
    }

    func openQualityIssue(_ check: CodeQualityCheck) {
        openFile(check.file)
    }

    func confirmControlItem(_ item: ControlItem) {
        updateControlItem(item, decision: .confirmed)
    }

    func markControlItemRedo(_ item: ControlItem) {
        updateControlItem(item, decision: .redo)
    }

    func openControlItemTarget(_ item: ControlItem) {
        if item.id.hasPrefix("rule:") {
            openTrackFile()
        } else if let path = filePath(for: item.target) {
            openFile(path)
        } else {
            selectedTab = .technical
            statusMessage = "已切到技术细节，可查看：\(item.title)"
        }
    }

    func copyReviewPrompt(for item: ControlItem) {
        copyToPasteboard("""
        请帮我验收 vibeComposer 标记的实现线索：

        标题：\(item.title)
        状态：\(item.status.label)
        目标：\(item.target)
        原因：\(item.reason)

        请检查它是否已经符合用户预期。如果符合，说明理由；如果不符合，请列出需要重做的最小修改项和验证方式。
        """)
        statusMessage = "已复制验收指令"
    }

    func copyRedoPrompt(for item: TrackableItem, notes: String? = nil) {
        let report = ReviewService.alignmentReport(for: item, in: data)
        copyToPasteboard(ReviewService.redoPrompt(for: item, report: report, notes: notes))
        statusMessage = "已复制重做指令：\(item.title)"
    }

    func copyAlignmentPrompt(for item: TrackableItem) {
        let report = ReviewService.alignmentReport(for: item, in: data)
        copyToPasteboard(VibeRoundService.alignmentPrompt(for: item, report: report))
        statusMessage = "已复制 AI 对齐检查指令：\(item.title)"
    }

    func saveRoundSettings(previewBaseURL: String, verificationCommand: String) {
        var state = data.controlState
        state.previewBaseURL = previewBaseURL
        state.verificationCommand = verificationCommand
        saveControlState(state)
        statusMessage = "已保存本轮工作包设置"
    }

    func startRound(title: String) {
        var state = data.controlState
        _ = VibeRoundService.startRound(in: &state, data: data, title: title)
        saveControlState(state)
        statusMessage = "已开始本轮工作包"
    }

    func endCurrentRound() {
        var state = data.controlState
        VibeRoundService.endRound(in: &state)
        saveControlState(state)
        statusMessage = "已结束本轮工作包"
    }

    func addRoundPrompt(prompt: String, responseSummary: String, model: String, source: String) {
        var state = data.controlState
        _ = VibeRoundService.addPrompt(to: &state, prompt: prompt, responseSummary: responseSummary, model: model, source: source)
        saveControlState(state)
        statusMessage = "已记录本轮 Prompt"
    }

    func openInspectionTarget(_ target: InspectionTarget) {
        if let openURL = target.openURL, let url = URL(string: openURL) {
            NSWorkspace.shared.open(url)
        } else if let path = target.path {
            openFile(path)
        } else {
            statusMessage = "这个检查目标没有可打开入口：\(target.title)"
        }
    }

    func copyInspectionCommand(_ target: InspectionTarget) {
        guard let command = target.command else {
            statusMessage = "这个检查目标没有命令：\(target.title)"
            return
        }
        copyToPasteboard(command)
        statusMessage = "已复制检查命令：\(target.title)"
    }

    func runVerificationCommand() {
        guard let projectURL else { return }
        let command = data.controlState.verificationCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            statusMessage = "请先填写验证命令"
            return
        }

        statusMessage = "正在运行验证命令..."
        let root = projectURL
        Task {
            let result = await Task.detached {
                Shell.run(["/bin/zsh", "-lc", command], currentDirectory: root)
            }.value

            var state = data.controlState
            var timeline = state.timeline
            let output = (result.output + result.error)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(1_200)
            timeline.insert(
                TimelineEvent.create(
                    kind: .verification,
                    title: result.succeeded ? "验证通过" : "验证失败",
                    details: output.isEmpty ? command : "\(command)\n\(output)"
                ),
                at: 0
            )
            state.timeline = timeline

            do {
                try Self.writeControlState(state, root: root)
                data.controlState = state
                statusMessage = result.succeeded ? "验证命令通过" : "验证命令失败：退出码 \(result.status)"
            } catch {
                errorMessage = "保存验证结果失败：\(error.localizedDescription)"
            }
        }
    }

    func copyFixPrompt(for check: VibeRuleCheck) {
        copyToPasteboard("""
        请处理 vibeComposer 检查到的问题：

        标题：\(check.title)
        严重级别：\(check.severity.rawValue)
        目标：\(check.target)
        规则：\(check.rule)
        详情：\(check.message)

        请先说明影响范围，再给出最小修复方案。文档登记类问题优先更新 .vibe/track.md；代码实现类问题不要盲目自动修改。
        """)
        statusMessage = "已复制修复指令"
    }

    func copyFixPrompt(for check: CodeQualityCheck) {
        copyToPasteboard("""
        请处理 vibeComposer 代码质量检查到的问题：

        文件：\(check.file)\(check.line.map { ":\($0)" } ?? "")
        分类：\(check.category)
        严重级别：\(check.severity.rawValue)
        问题：\(check.message)
        建议：\(check.suggestion ?? "请给出最小安全修复。")

        请先解释问题原因，再给出最小修改方案和验证命令。
        """)
        statusMessage = "已复制修复指令"
    }

    func openFile(_ relativePath: String) {
        guard let projectURL else { return }
        NSWorkspace.shared.open(projectURL.child(relativePath))
    }

    func saveControlState(_ state: UserControlState) {
        guard let projectURL else { return }
        do {
            try Self.writeControlState(state, root: projectURL)
            self.data.controlState = state
            refresh()
        } catch {
            errorMessage = "保存控制状态失败：\(error.localizedDescription)"
        }
    }

    static func writeControlState(_ state: UserControlState, root: URL) throws {
        let url = root.child(".vibe-tracking.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: url)
    }

    static func loadControlState(root: URL) -> UserControlState {
        let url = root.child(".vibe-tracking.json")
        guard let data = try? Data(contentsOf: url) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(UserControlState.self, from: data)) ?? .empty
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func updateControlItem(_ item: ControlItem, decision: UserDecision) {
        guard !item.id.hasPrefix("rule:") else {
            statusMessage = "规则问题请使用问题操作里的修复或复制指令"
            return
        }

        var state = data.controlState
        if let requirementID = item.target.removingPrefix("requirement:") {
            guard let index = state.requirements.firstIndex(where: { $0.id == requirementID }) else { return }
            state.requirements[index].status = decision == .confirmed ? .done : .redo
            state.requirements[index].updatedAt = Date()
        } else {
            state.decisions[item.target] = UserControlDecision(decision: decision, updatedAt: Date())
        }

        if decision == .confirmed {
            state.baseline = DiffTracker.updateBaseline(state.baseline, with: data, acceptedIDs: [item.target])
        }

        saveControlState(state)
        statusMessage = decision == .confirmed ? "已确认完成：\(item.title)" : "已标记重做：\(item.title)"
    }

    private func filePath(for target: String) -> String? {
        if let pagePath = target.removingPrefix("page:") {
            return pagePath
        }
        if target.contains("/") || target.contains(".") {
            return target
        }
        return nil
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case overview
    case control
    case board
    case aiWork
    case generations
    case alignment
    case rounds
    case technical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .control: "验收控制"
        case .overview: "总览"
        case .board: "已有实现"
        case .aiWork: "AI 工作"
        case .generations: "记录生成"
        case .alignment: "对齐分析"
        case .rounds: "轮次历史"
        case .technical: "技术细节"
        }
    }

    var symbol: String {
        switch self {
        case .control: "checkmark.shield"
        case .overview: "square.grid.2x2"
        case .board: "rectangle.split.3x1"
        case .aiWork: "sparkles"
        case .generations: "doc.badge.plus"
        case .alignment: "arrow.left.arrow.right"
        case .rounds: "target"
        case .technical: "chevron.left.forwardslash.chevron.right"
        }
    }
}
