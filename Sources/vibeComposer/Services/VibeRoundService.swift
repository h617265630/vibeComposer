import Foundation

enum VibeRoundService {
    static func startRound(in state: inout UserControlState, data: ActivityData, title: String) -> VibeRound {
        let round = VibeRound(
            id: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "未命名轮次",
            goal: state.goal,
            startedAt: Date(),
            endedAt: nil,
            status: .active,
            requirementIDs: state.requirements.map(\.id),
            prompts: [],
            startGenerationCount: state.generations.count,
            startBaselineCount: state.baseline?.itemFingerprints.count ?? 0,
            acceptedItemIDs: [],
            redoItemIDs: [],
            verificationPlan: verificationPlan(for: data, customCommand: state.verificationCommand)
        )
        state.currentRound = round
        insertTimeline(.roundStart, title: "开始轮次：\(round.title)", details: state.goal, state: &state)
        return round
    }

    static func addPrompt(to state: inout UserControlState, prompt: String, responseSummary: String, model: String, source: String) -> VibePromptRecord {
        let record = VibePromptRecord(
            id: UUID().uuidString,
            timestamp: Date(),
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            responseSummary: responseSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "未记录模型",
            source: source.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "手动记录"
        )

        var round = state.currentRound ?? VibeRound(
            id: UUID().uuidString,
            title: "临时轮次",
            goal: state.goal,
            startedAt: Date(),
            endedAt: nil,
            status: .active,
            requirementIDs: state.requirements.map(\.id),
            prompts: [],
            startGenerationCount: state.generations.count,
            startBaselineCount: state.baseline?.itemFingerprints.count ?? 0,
            acceptedItemIDs: [],
            redoItemIDs: [],
            verificationPlan: nil
        )
        round.prompts.insert(record, at: 0)
        state.currentRound = round
        insertTimeline(.prompt, title: "记录 Prompt：\(record.source)", details: record.prompt, state: &state)
        return record
    }

    static func endRound(in state: inout UserControlState) {
        guard var round = state.currentRound else { return }
        round.status = .completed
        round.endedAt = Date()
        round.acceptedItemIDs = state.decisions.filter { $0.value.decision == .confirmed }.map(\.key).sorted()
        round.redoItemIDs = state.decisions.filter { $0.value.decision == .redo }.map(\.key).sorted()
        var rounds = state.rounds
        rounds.insert(round, at: 0)
        state.rounds = rounds
        state.currentRound = nil
        insertTimeline(.roundEnd, title: "结束轮次：\(round.title)", details: "通过 \(round.acceptedItemIDs.count) 项，重做 \(round.redoItemIDs.count) 项", state: &state)
    }

    static func inspectionTargets(for data: ActivityData, previewBaseURL: String) -> [InspectionTarget] {
        let base = previewBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageTargets = data.frontendPages.map { page in
            InspectionTarget(
                kind: .page,
                title: page.name,
                detail: page.route.isEmpty ? page.path : page.route,
                path: page.path,
                openURL: url(base: base, path: page.route),
                command: nil
            )
        }

        let apiTargets = data.backendApis.map { api in
            let openURL = url(base: base, path: api.endpoint)
            return InspectionTarget(
                kind: .api,
                title: "\(api.method.rawValue) \(api.endpoint)",
                detail: api.path,
                path: api.path,
                openURL: openURL,
                command: openURL.map { "curl -i -X \(api.method.rawValue) \($0)" }
            )
        }

        let databaseTargets = data.databaseTables.map { table in
            InspectionTarget(
                kind: .database,
                title: table.name,
                detail: "\(table.columns.count) 字段，\(table.relations.count) 关系",
                path: nil,
                openURL: nil,
                command: nil
            )
        }

        return pageTargets + apiTargets + databaseTargets
    }

    static func alignmentPrompt(for item: TrackableItem, report: AlignmentReport) -> String {
        let criteria = report.acceptanceCriteria.isEmpty
            ? "- 未填写验收标准"
            : report.acceptanceCriteria.map { "- \($0)" }.joined(separator: "\n")
        let pages = report.matchedPages.map { "- \($0.title)：\($0.detail)" }.joined(separator: "\n").nonEmpty ?? "- 无页面线索"
        let apis = report.matchedApis.map { "- \($0.title)：\($0.detail)" }.joined(separator: "\n").nonEmpty ?? "- 无 API 线索"
        let tables = report.matchedTables.map { "- \($0.title)：\($0.detail)" }.joined(separator: "\n").nonEmpty ?? "- 无数据库线索"
        let missing = report.missingSignals.map { "- \($0)" }.joined(separator: "\n").nonEmpty ?? "- 暂无缺失线索"
        let risks = report.riskSignals.map { "- \($0)" }.joined(separator: "\n").nonEmpty ?? "- 暂无风险线索"

        return """
        请判断实现是否满足业务需求，并给出通过/重做建议。

        验收项：\(item.title)
        业务需求：\(report.requirementTitle ?? "未找到直接关联的业务需求")
        业务价值：\(report.requirementValue ?? item.businessMeaning)

        验收标准：
        \(criteria)

        页面线索：
        \(pages)

        API 线索：
        \(apis)

        数据库线索：
        \(tables)

        缺失线索：
        \(missing)

        风险线索：
        \(risks)

        请输出：
        1. 是否满足业务需求
        2. 哪些验收标准已经满足
        3. 哪些地方需要人工肉眼确认
        4. 如需重做，给出最小修改项
        """
    }

    static func verificationPlan(for data: ActivityData, customCommand: String) -> VerificationPlan {
        var checks: [VerificationCheck] = []
        if let command = customCommand.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            checks.append(VerificationCheck(id: "custom-command", kind: .command, title: "运行自定义验证命令", detail: "用户配置的项目验证命令", command: command))
        }
        if data.unitTests.totalTests > 0 {
            let frameworks = data.unitTests.frameworks.joined(separator: "、").nonEmpty ?? "已识别测试框架"
            checks.append(VerificationCheck(id: "tests", kind: .test, title: "运行测试（\(data.unitTests.totalTests) 个）", detail: frameworks, command: nil))
        }
        if !data.frontendPages.isEmpty {
            checks.append(VerificationCheck(id: "manual-pages", kind: .manual, title: "肉眼验收页面", detail: "\(data.frontendPages.count) 个页面需要确认视觉和交互", command: nil))
        }
        if !data.backendApis.isEmpty {
            checks.append(VerificationCheck(id: "api-check", kind: .api, title: "检查 API 可用性", detail: "\(data.backendApis.count) 个接口需要确认请求/响应", command: nil))
        }
        if !data.databaseTables.isEmpty {
            checks.append(VerificationCheck(id: "database-check", kind: .database, title: "检查数据库结构", detail: "\(data.databaseTables.count) 张表需要确认字段和关系", command: nil))
        }
        if checks.isEmpty {
            checks.append(VerificationCheck(id: "manual-default", kind: .manual, title: "肉眼验收本轮实现", detail: "未识别到自动验证线索，请人工检查关键文件和运行结果", command: nil))
        }
        return VerificationPlan(id: UUID().uuidString, createdAt: Date(), checks: checks)
    }

    private static func url(base: String, path: String) -> String? {
        guard !base.isEmpty else { return nil }
        let normalizedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let path = path.nonEmpty else { return normalizedBase }
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        return "\(normalizedBase)\(normalizedPath)"
    }

    private static func insertTimeline(_ kind: TimelineEventKind, title: String, details: String, state: inout UserControlState) {
        var timeline = state.timeline
        timeline.insert(TimelineEvent.create(kind: kind, title: title, details: details), at: 0)
        state.timeline = timeline
    }
}
