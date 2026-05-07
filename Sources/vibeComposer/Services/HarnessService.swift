import Foundation

enum HarnessService {
    static let vibeDirectory = ".vibe"
    static let requiredFiles = ["track.md", "rules.md", "workflow.md"]

    static func status(root: URL) -> VibeHarnessStatus {
        let states = Dictionary(uniqueKeysWithValues: requiredFiles.map { fileName in
            (fileName, FileManager.default.fileExists(atPath: root.child("\(vibeDirectory)/\(fileName)").path))
        })
        let missing = requiredFiles.filter { states[$0] != true }
        return VibeHarnessStatus(isComplete: missing.isEmpty, missingFiles: missing, requiredFiles: states)
    }

    static func generate(root: URL, activity: ActivityData? = nil) throws {
        let vibe = root.child(vibeDirectory)
        try FileManager.default.createDirectory(at: vibe, withIntermediateDirectories: true)
        let structure = ProjectScanner.projectStructure(root: root)
        let frontend = activity?.frontendScan ?? ProjectScanner.scanFrontendFull(root: root)
        let backendApis = ProjectScanner.detectFastApiRoutes(root: root)
        let databaseTables = ProjectScanner.detectDatabaseTableNames(root: root)
        let aiLogic = ProjectScanner.detectAiLogicNames(root: root)
        let templates = defaultTemplates(
            projectName: root.lastPathComponent,
            structure: structure,
            frontendPages: frontend.pages,
            backendApis: backendApis,
            databaseTables: databaseTables,
            aiLogic: aiLogic
        )

        for fileName in requiredFiles {
            let url = vibe.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                try templates[fileName]?.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    static func repairTrackRegistration(root: URL, for check: VibeRuleCheck) throws -> Bool {
        let trackURL = root.child("\(vibeDirectory)/track.md")
        let content = try String(contentsOf: trackURL, encoding: .utf8)
        guard let repaired = repairedTrackContent(content, for: check), repaired != content else {
            return false
        }
        try repaired.write(to: trackURL, atomically: true, encoding: .utf8)
        return true
    }

    static func repairedTrackContent(_ content: String, for check: VibeRuleCheck) -> String? {
        guard let section = trackSection(for: check) else { return nil }
        return appendTrackItem(check.target, toSection: section, in: content)
    }

    static func canRepairTrackRegistration(_ check: VibeRuleCheck) -> Bool {
        trackSection(for: check) != nil
    }

    static func ruleCheckReport(root: URL, frontendPages: [FrontendPage], recentChanges: [FileChange]) -> VibeRuleCheckReport {
        let rulesURL = root.child("\(vibeDirectory)/rules.md")
        let trackURL = root.child("\(vibeDirectory)/track.md")
        guard let rulesContent = try? String(contentsOf: rulesURL, encoding: .utf8),
              let trackContent = try? String(contentsOf: trackURL, encoding: .utf8)
        else {
            return VibeRuleCheckReport(isConfigured: false, rules: [], checks: [], errors: 0, warnings: 0, info: 0)
        }

        let rules = parseRuleLines(rulesContent)
        let track = parseTrackInventory(trackContent)
        let currentApis = ProjectScanner.detectFastApiRoutes(root: root)
        let currentTables = ProjectScanner.detectDatabaseTableNames(root: root)
        let currentAiLogic = ProjectScanner.detectAiLogicNames(root: root)
        var checks: [VibeRuleCheck] = []

        if hasRule(rules, #"新\s*API|Backend API|track\.md"#) {
            for api in currentApis where !track.backendApis.contains(normalizeApi(api)) {
                checks.append(makeCheck(.warning, "新 API 未登记到 track.md", "发现 \(api)，但 .vibe/track.md 的 Backend API 中没有记录。", findRule(rules, #"新\s*API|Backend API|track\.md"#), api))
            }
        }

        if hasRule(rules, #"不允许删除已有\s*API|禁止删除.*API"#) {
            let current = Set(currentApis.map(normalizeApi))
            for api in track.backendApis where !current.contains(api) {
                checks.append(makeCheck(.error, "已有 API 被删除", "track.md 中登记了 \(api)，但当前代码扫描不到这个 FastAPI 路由。", findRule(rules, #"不允许删除已有\s*API|禁止删除.*API"#), api))
            }
        }

        if hasRule(rules, #"新页面|Frontend Pages|track\.md"#) {
            for page in frontendPages where !trackHasFrontendPage(track.frontendPages, page) {
                let target = ProjectScanner.formatFrontendPageTrackItem(page)
                checks.append(makeCheck(.warning, "新页面未登记到 track.md", "发现页面 \(target)，但 .vibe/track.md 的 Frontend Pages 中没有记录。", findRule(rules, #"新页面|Frontend Pages|track\.md"#), target))
            }
        }

        if hasRule(rules, #"新表|Database|track\.md"#) {
            for table in currentTables where !track.databaseTables.contains(table.normalizedEntity()) {
                checks.append(makeCheck(.warning, "新表未登记到 track.md", "发现数据库表 \(table)，但 .vibe/track.md 的 Database 中没有记录。", findRule(rules, #"新表|Database|track\.md"#), table))
            }
        }

        if hasRule(rules, #"AI Logic|AI\s*模块|AI\s*逻辑|track\.md"#) {
            for logic in currentAiLogic where !track.aiLogic.contains(logic.normalizedEntity()) {
                checks.append(makeCheck(.warning, "AI 逻辑未登记到 track.md", "发现 AI 逻辑 \(logic)，但 .vibe/track.md 的 AI Logic 中没有记录。", findRule(rules, #"AI Logic|AI\s*模块|AI\s*逻辑|track\.md"#), logic))
            }
        }

        if hasRule(rules, #"数据库字段|migration|迁移"#), hasDatabaseModelChange(recentChanges), !hasMigrationChange(recentChanges) {
            checks.append(makeCheck(.warning, "数据库模型变更缺少 migration", "检测到数据库模型相关文件变更，但最近变更里没有 migration 文件。", findRule(rules, #"数据库字段|migration|迁移"#), "database models"))
        }

        if hasRule(rules, #"数据库字段|新表|Database|track\.md"#), hasDatabaseModelChange(recentChanges), !hasDatabaseDocChange(recentChanges) {
            checks.append(makeCheck(.warning, "数据库认知文档未更新", "检测到数据库模型相关文件变更，但最近没有更新 .vibe/track.md 或 database.md。", findRule(rules, #"数据库字段|新表|Database|track\.md"#), "database documentation"))
        }

        return VibeRuleCheckReport(
            isConfigured: true,
            rules: rules,
            checks: checks,
            errors: checks.filter { $0.severity == .error }.count,
            warnings: checks.filter { $0.severity == .warning }.count,
            info: checks.filter { $0.severity == .info }.count
        )
    }

    static func workflowReport(
        root: URL,
        controlState: UserControlState,
        frontendPages: [FrontendPage],
        recentChanges: [FileChange],
        ruleChecks: [VibeRuleCheck]
    ) -> VibeWorkflowReport {
        let workflowURL = root.child("\(vibeDirectory)/workflow.md")
        guard let content = try? String(contentsOf: workflowURL, encoding: .utf8) else {
            return VibeWorkflowReport(isConfigured: false, title: "Harness Workflow", currentTask: "未配置 workflow.md", steps: [], done: 0, active: 0, blocked: 0, pending: 0)
        }

        let parsed = parseWorkflowChecklist(content)
        let currentTask = inferCurrentTask(controlState)
        let currentApis = ProjectScanner.detectFastApiRoutes(root: root)
        let currentTables = ProjectScanner.detectDatabaseTableNames(root: root)
        let currentAi = ProjectScanner.detectAiLogicNames(root: root)
        let combinedRules = ruleChecks.map { "\($0.title) \($0.message)" }.joined(separator: "\n")

        let steps = parsed.steps.enumerated().map { index, step in
            let status = inferWorkflowStepStatus(
                title: step.title,
                checked: step.checked,
                hasGoal: !currentTask.isEmpty && currentTask != "未设置当前任务",
                hasTrackDrift: combinedRules.contains("track.md") || combinedRules.contains("未登记"),
                hasApiDrift: combinedRules.contains("API"),
                hasDatabaseDrift: combinedRules.contains("数据库") || combinedRules.contains("Database") || combinedRules.contains("migration"),
                hasPageDrift: combinedRules.contains("页面") || combinedRules.contains("Frontend Pages"),
                hasAiDrift: combinedRules.contains("AI"),
                hasFrontendPages: !frontendPages.isEmpty,
                hasBackendApis: !currentApis.isEmpty,
                hasDatabaseTables: !currentTables.isEmpty,
                hasAiLogic: !currentAi.isEmpty,
                hasRecentChanges: !recentChanges.isEmpty,
                hasBlockingDrift: ruleChecks.contains { $0.severity == .error }
            )
            return VibeWorkflowStep(id: "workflow-step-\(index)-\(step.title.normalizedEntity())", title: step.title, status: status.status, reason: status.reason)
        }

        return VibeWorkflowReport(
            isConfigured: true,
            title: parsed.title,
            currentTask: currentTask,
            steps: steps,
            done: steps.filter { $0.status == .done }.count,
            active: steps.filter { $0.status == .active }.count,
            blocked: steps.filter { $0.status == .blocked }.count,
            pending: steps.filter { $0.status == .pending }.count
        )
    }
}

private extension HarnessService {
    static func defaultTemplates(
        projectName: String,
        structure: [TreeNode],
        frontendPages: [FrontendPage],
        backendApis: [String],
        databaseTables: [String],
        aiLogic: [String]
    ) -> [String: String] {
        let mapLines = renderProjectMap(structure)
        let pageLines = frontendPages.isEmpty ? "- 暂未识别到前端页面" : frontendPages.map { "- \(ProjectScanner.formatFrontendPageTrackItem($0))" }.joined(separator: "\n")
        let apiLines = backendApis.isEmpty ? "- 暂未识别到 FastAPI 路由" : backendApis.map { "- \($0)" }.joined(separator: "\n")
        let dbLines = databaseTables.isEmpty ? "- 暂未识别到数据库表" : databaseTables.map { "- \($0)" }.joined(separator: "\n")
        let aiLines = aiLogic.isEmpty ? "- 暂未识别到 AI 逻辑函数" : aiLogic.map { "- \($0)" }.joined(separator: "\n")
        let now = VibeDateFormatter.iso8601.string(from: Date())

        return [
            "track.md": """
            # Project Track

            Project: \(projectName)
            Generated At: \(now)

            ## Project Map
            \(mapLines)

            ## Frontend Pages
            \(pageLines)

            ## Backend API
            \(apiLines)

            ## Database
            \(dbLines)

            ## AI Logic
            \(aiLines)

            ## Notes
            - 在每次重大变更后更新本文件，保持项目地图与能力清单同步。
            - 如需补充业务语义，可在对应条目后追加一行说明。
            """,
            "rules.md": """
            # Harness Rules

            ## Editing Rules
            - 新增功能必须更新 track.md。
            - 不允许删除已有 API。
            - 不允许直接修改数据库字段，必须写 migration。
            - 新页面必须登记到 Frontend Pages。
            - 新 API 必须登记到 Backend API。
            - 新表必须登记到 Database。
            - 新 AI Logic 必须登记到 AI Logic。

            ## Quality Rules
            - 每次改动都要做最小化验证（构建、类型检查或关键测试）。
            - 输出必须标注影响范围与回滚点。
            - 遇到不确定上下文时先记录假设，再执行。
            """,
            "workflow.md": """
            # Harness Workflow

            ## Add New Feature Workflow
            - [ ] 描述功能目标
            - [ ] 更新 track.md
            - [ ] 设计数据库表
            - [ ] 设计 API
            - [ ] 实现前端页面/组件
            - [ ] 实现后端逻辑
            - [ ] 检查影响范围
            - [ ] 更新文档

            ## Notes
            - 插件会把 checklist 映射成当前任务进度。
            - track.md / rules.md / workflow.md 共同组成 harness：认知地图、约束层、执行流程。
            """
        ]
    }

    static func renderProjectMap(_ nodes: [TreeNode], maxLines: Int = 200) -> String {
        guard !nodes.isEmpty else { return "- 暂未识别到项目结构" }
        var lines: [String] = []
        func append(_ nodes: [TreeNode], level: Int) {
            for node in nodes where lines.count < maxLines {
                let indent = String(repeating: "  ", count: level)
                lines.append("\(indent)- \(node.name)\(node.type == .folder ? "/" : "")")
                append(node.children, level: level + 1)
            }
        }
        append(nodes, level: 0)
        if lines.count >= maxLines { lines.append("- ... (项目结构过大，已截断)") }
        return lines.joined(separator: "\n")
    }

    static func parseRuleLines(_ content: String) -> [String] {
        content.components(separatedBy: .newlines).compactMap { line in
            line.firstMatch(#"^\s*[-*]\s+(.+)$"#)?.dropFirst().first?.trimmingCharacters(in: .whitespaces)
        }
    }

    static func parseTrackInventory(_ content: String) -> (frontendPages: [String], backendApis: Set<String>, databaseTables: Set<String>, aiLogic: Set<String>) {
        (
            parseSectionItems(content, "Frontend Pages").map { $0.normalizedEntity() },
            Set(parseSectionItems(content, "Backend API").map(normalizeApi)),
            Set(parseSectionItems(content, "Database").map { $0.normalizedEntity() }),
            Set(parseSectionItems(content, "AI Logic").map { $0.normalizedEntity() })
        )
    }

    static func parseSectionItems(_ content: String, _ heading: String) -> [String] {
        let escaped = NSRegularExpression.escapedPattern(for: heading)
        guard let match = content.firstMatch("(?s)(?:^|\\n)##\\s+\(escaped)\\s*\\n(.*?)(?=\\n##\\s+|$)"), match.count > 1 else { return [] }
        return match[1].components(separatedBy: .newlines).compactMap { line in
            guard let item = line.firstMatch(#"^\s*-\s+(.+)$"#)?.dropFirst().first?.trimmingCharacters(in: .whitespaces),
                  !item.hasPrefix("暂未识别"),
                  !item.hasPrefix("...")
            else { return nil }
            return item
        }
    }

    static func trackSection(for check: VibeRuleCheck) -> String? {
        let title = check.title
        if title.contains("新 API 未登记") { return "Backend API" }
        if title.contains("新页面未登记") { return "Frontend Pages" }
        if title.contains("新表未登记") { return "Database" }
        if title.contains("AI 逻辑未登记") { return "AI Logic" }
        return nil
    }

    static func appendTrackItem(_ item: String, toSection heading: String, in content: String) -> String {
        let normalizedItem = item.normalizedEntity()
        let escaped = NSRegularExpression.escapedPattern(for: heading)
        guard let regex = try? NSRegularExpression(pattern: #"(?s)((?:^|\n)##\s+\#(escaped)\s*\n)(.*?)(?=\n##\s+|$)"#) else {
            return content
        }

        let fullRange = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: fullRange),
              let headerRange = Range(match.range(at: 1), in: content),
              let bodyRange = Range(match.range(at: 2), in: content),
              let replaceRange = Range(match.range(at: 0), in: content)
        else {
            let suffix = content.hasSuffix("\n") ? "" : "\n"
            return "\(content)\(suffix)\n## \(heading)\n- \(item)\n"
        }

        let header = String(content[headerRange])
        let body = String(content[bodyRange])
        var items = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard line.hasPrefix("- ") else { return false }
                let value = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                return !value.hasPrefix("暂未识别") && !value.hasPrefix("...")
            }

        if items.contains(where: { String($0.dropFirst(2)).normalizedEntity() == normalizedItem }) {
            return content
        }

        items.append("- \(item)")
        let nextSection = header + items.joined(separator: "\n") + "\n"
        var output = content
        output.replaceSubrange(replaceRange, with: nextSection)
        return output
    }

    static func normalizeApi(_ value: String) -> String {
        guard let match = value.firstMatch(#"^(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD)\s+(.+)$"#, options: [.caseInsensitive]), match.count > 2 else {
            return value.normalizedEntity()
        }
        return "\(match[1].uppercased()) \(match[2].trimmingCharacters(in: .whitespaces))"
    }

    static func hasRule(_ rules: [String], _ pattern: String) -> Bool {
        rules.contains { $0.containsRegex(pattern, options: [.caseInsensitive]) }
    }

    static func findRule(_ rules: [String], _ pattern: String) -> String {
        rules.first { $0.containsRegex(pattern, options: [.caseInsensitive]) } ?? "未命名规则"
    }

    static func makeCheck(_ severity: VibeRuleSeverity, _ title: String, _ message: String, _ rule: String, _ target: String) -> VibeRuleCheck {
        VibeRuleCheck(id: "\(severity.rawValue)-\(title.normalizedEntity())-\(target.normalizedEntity())", severity: severity, title: title, message: message, rule: rule, target: target)
    }

    static func trackHasFrontendPage(_ trackPages: [String], _ page: FrontendPage) -> Bool {
        let candidates = [page.route, page.path, page.name, ProjectScanner.formatFrontendPageTrackItem(page)]
            .filter { !$0.isEmpty }
            .map { $0.normalizedEntity() }
        return trackPages.contains { track in candidates.contains { track.contains($0) } }
    }

    static func hasMigrationChange(_ changes: [FileChange]) -> Bool {
        changes.contains { $0.relativePath.lowercased().containsRegex(#"(^|/)(migrations?|alembic/versions|prisma/migrations)(/|$)"#) }
    }

    static func hasDatabaseModelChange(_ changes: [FileChange]) -> Bool {
        changes.contains {
            $0.type != .deleted
            && $0.relativePath.lowercased().hasSuffix(".py")
            && $0.relativePath.lowercased().containsRegex(#"(^|/)(models?|schemas?|entities)(/|$)"#)
        }
    }

    static func hasDatabaseDocChange(_ changes: [FileChange]) -> Bool {
        changes.contains {
            let path = $0.relativePath.lowercased()
            return path == ".vibe/track.md" || path == ".vibe/database.md" || path == "database.md" || path.hasSuffix("/database.md")
        }
    }

    static func parseWorkflowChecklist(_ content: String) -> (title: String, steps: [(title: String, checked: Bool)]) {
        let title = content.firstMatch(#"(?m)^#\s+(.+)$"#)?.dropFirst().first?.trimmingCharacters(in: .whitespaces)
            ?? content.firstMatch(#"(?m)^##\s+(.+)$"#)?.dropFirst().first?.trimmingCharacters(in: .whitespaces)
            ?? "Harness Workflow"
        let steps = content.components(separatedBy: .newlines).compactMap { line -> (String, Bool)? in
            if let match = line.firstMatch(#"^\s*[-*]\s+\[( |x|X)\]\s+(.+)$"#), match.count > 2 {
                return (match[2].trimmingCharacters(in: .whitespaces), match[1].lowercased() == "x")
            }
            if let match = line.firstMatch(#"^\s*[-*]\s+(.+)$"#), match.count > 1 {
                let title = match[1].trimmingCharacters(in: .whitespaces)
                if !title.hasPrefix("插件会") && !title.hasPrefix("track.md") { return (title, false) }
            }
            return nil
        }
        return (title, steps)
    }

    static func inferCurrentTask(_ state: UserControlState) -> String {
        state.requirements.first { $0.status == .inProgress }?.title
            ?? state.requirements.first { $0.status == .planned }?.title
            ?? state.requirements.first { $0.status == .needsReview }?.title
            ?? state.goal.nonEmpty
            ?? "未设置当前任务"
    }

    static func inferWorkflowStepStatus(
        title: String,
        checked: Bool,
        hasGoal: Bool,
        hasTrackDrift: Bool,
        hasApiDrift: Bool,
        hasDatabaseDrift: Bool,
        hasPageDrift: Bool,
        hasAiDrift: Bool,
        hasFrontendPages: Bool,
        hasBackendApis: Bool,
        hasDatabaseTables: Bool,
        hasAiLogic: Bool,
        hasRecentChanges: Bool,
        hasBlockingDrift: Bool
    ) -> (status: VibeWorkflowStepStatus, reason: String) {
        if checked { return (.done, "workflow.md 已勾选完成") }
        let lower = title.lowercased()
        if lower.containsRegex("目标|需求|goal|intake") { return hasGoal ? (.done, "已设置当前任务或项目目标") : (.active, "需要先明确当前任务目标") }
        if lower.contains("track") { return hasTrackDrift ? (.blocked, "检测到代码和 track.md 存在偏移") : (.done, "当前没有 track.md 登记偏移") }
        if lower.containsRegex("数据库|表|database|migration") { return hasDatabaseDrift ? (.blocked, "数据库相关变更需要同步登记或 migration") : (hasDatabaseTables ? (.done, "已识别数据库表") : (.pending, "尚未识别数据库设计结果")) }
        if lower.containsRegex(#"\bapi\b|后端接口|接口"#) { return hasApiDrift ? (.blocked, "API 与 track.md / rules.md 存在偏移") : (hasBackendApis ? (.done, "已识别后端 API") : (.pending, "尚未识别 API 设计结果")) }
        if lower.containsRegex("前端|页面|组件|frontend|component") { return hasPageDrift ? (.blocked, "前端页面未同步登记") : (hasFrontendPages ? (.done, "已识别前端页面或组件") : (.pending, "尚未识别前端实现")) }
        if lower.containsRegex("ai|agent|chain|prompt") { return hasAiDrift ? (.blocked, "AI Logic 未同步登记") : (hasAiLogic ? (.done, "已识别 AI Logic") : (.pending, "尚未识别 AI 模块")) }
        if lower.containsRegex("影响|检查|verify|review") { return hasBlockingDrift ? (.blocked, "存在阻断级 Drift，需要先处理") : (.active, "等待确认影响范围") }
        if lower.containsRegex("文档|doc") { return hasTrackDrift ? (.blocked, "文档/track.md 仍需同步") : (hasRecentChanges ? (.active, "已有代码变更，建议收尾更新文档") : (.pending, "等待代码变更后更新")) }
        return hasRecentChanges ? (.active, "根据最近代码变更推断为进行中") : (.pending, "等待任务推进")
    }
}
