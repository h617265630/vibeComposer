import Foundation

enum ProgressStatus: String, Codable, Hashable {
    case done
    case baseline
    case inProgress = "in-progress"
    case needsReview = "needs-review"
    case redo
    case risk

    var label: String {
        switch self {
        case .done: "完成"
        case .baseline: "基线"
        case .inProgress: "进行中"
        case .needsReview: "需验收"
        case .redo: "重做"
        case .risk: "风险"
        }
    }
}

enum ConfidenceLevel: String, Codable, Hashable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high: "高"
        case .medium: "中"
        case .low: "低"
        }
    }
}

struct Evidence: Identifiable, Codable, Hashable {
    var id: String { "\(label)-\(detail)" }
    let label: String
    let detail: String
}

struct TrackableItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let kind: String
    let status: ProgressStatus
    let confidence: ConfidenceLevel
    let confidenceReason: String
    let businessMeaning: String
    let lastTouched: String?
    let evidence: [Evidence]
}

struct AiWorkItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let timeAgo: String
    let evidence: [Evidence]
}

struct ControlItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let reason: String
    let target: String
    let status: ProgressStatus
}

struct AiInstruction: Codable, Hashable {
    let title: String
    let prompt: String
    let source: String
}

struct ProjectProgress: Codable, Hashable {
    let headline: String
    let healthLabel: String
    let doneCount: Int
    let reviewCount: Int
    let riskCount: Int
    let nextStep: String
    let pages: [TrackableItem]
    let features: [TrackableItem]
    let aiWork: [AiWorkItem]
    let controls: [ControlItem]
    let aiInstruction: AiInstruction
}

enum ProgressDeriver {
    static func derive(from data: ActivityData) -> ProjectProgress {
        let pages = data.frontendPages.map { page in
            pageItem(page, changes: data.recentChanges, controlState: data.controlState)
        }
        let requirementFeatures = data.controlState.requirements.filter { !$0.title.isEmpty }.map {
            requirementItem($0, data: data)
        }
        let apiFeatures = apiItems(data.backendApis, changes: data.recentChanges, controlState: data.controlState)
        let systemFeatures = systemItems(data)
        let features = requirementFeatures + apiFeatures + systemFeatures
        let allItems = pages + features
        let controls = controlItems(items: allItems, data: data)
        let done = allItems.filter { $0.status == .done }.count
        let review = allItems.filter { $0.status == .needsReview }.count
        let risk = allItems.filter { $0.status == .risk }.count
        let active = allItems.filter { $0.status == .inProgress }.count

        return ProjectProgress(
            headline: headline(pages: pages.count, features: features.count, review: review, risk: risk, goal: data.controlState.goal, requirements: data.controlState.requirements.count),
            healthLabel: risk > 0 ? "需要先看风险" : review > 0 ? "有成果需验收" : active > 0 ? "正在推进" : "等待更多项目线索",
            doneCount: done,
            reviewCount: review,
            riskCount: risk,
            nextStep: nextStep(controls: controls, pages: pages.count, features: features.count, goal: data.controlState.goal),
            pages: pages,
            features: features,
            aiWork: aiWork(data),
            controls: controls,
            aiInstruction: aiInstruction(data: data, controls: controls, items: allItems)
        )
    }

    private static func pageItem(_ page: FrontendPage, changes: [FileChange], controlState: UserControlState) -> TrackableItem {
        let changed = changes.first { change in
            page.path.contains(change.relativePath) || change.relativePath.contains(page.path)
        }
        let hasRoute = !page.route.isEmpty && page.route != "/"
        let hasStructure = page.componentCount > 0 || !page.localComponents.isEmpty || !page.sharedComponents.isEmpty
        let confidence: ConfidenceLevel = hasRoute && hasStructure ? .high : hasRoute || hasStructure ? .medium : .low
        let id = "page:\(page.path)"
        let fingerprint = ProjectBaselineService.fingerprints(from: ActivityData.empty.replacing(frontendPages: [page]))[id]
        let status = resolvedStatus(
            for: id,
            fingerprint: fingerprint,
            fallback: changed != nil || hasRoute || hasStructure ? .baseline : .inProgress,
            controlState: controlState
        )

        return TrackableItem(
            id: id,
            title: page.name,
            kind: "page",
            status: status,
            confidence: confidence,
            confidenceReason: confidence == .high ? "页面有路由和组件结构。" : "页面有部分实现线索，需要确认完整度。",
            businessMeaning: page.route == "/" ? "这是项目入口或核心界面。" : "这个页面承载 \(page.route) 对应的用户路径。",
            lastTouched: changed.map { VibeDateFormatter.display.string(from: $0.timestamp) } ?? page.lastModified.map { VibeDateFormatter.display.string(from: $0) },
            evidence: [
                Evidence(label: "页面路径", detail: page.route.isEmpty ? page.path : page.route),
                Evidence(label: "页面结构", detail: "\(page.componentCount) 个组件，\(page.hooksUsed.count) 个交互线索"),
                Evidence(label: "文件", detail: page.path)
            ]
        )
    }

    private static func requirementItem(_ requirement: ProjectRequirement, data: ActivityData) -> TrackableItem {
        let evidence = requirementEvidence(requirement, data: data)
        let status: ProgressStatus = {
            switch requirement.status {
            case .done: .done
            case .redo: .redo
            case .needsReview: .needsReview
            case .inProgress: evidence.isEmpty ? .inProgress : .needsReview
            case .planned: evidence.isEmpty ? .inProgress : .needsReview
            }
        }()
        return TrackableItem(
            id: "requirement:\(requirement.id)",
            title: requirement.title,
            kind: "feature",
            status: status,
            confidence: evidence.count >= 2 ? .high : evidence.isEmpty ? .low : .medium,
            confidenceReason: evidence.isEmpty ? "用户需求还没有明显实现证据。" : "匹配到实现线索，需要用户确认是否满足需求。",
            businessMeaning: requirement.userValue.isEmpty ? "这是用户明确写下的需求。" : requirement.userValue,
            lastTouched: VibeDateFormatter.display.string(from: requirement.updatedAt),
            evidence: [
                Evidence(label: "优先级", detail: requirement.priority.label),
                Evidence(label: "验收标准", detail: requirement.acceptanceCriteria.isEmpty ? "未填写" : "\(requirement.acceptanceCriteria.count) 条"),
                Evidence(label: "实现线索", detail: evidence.prefix(3).joined(separator: "、").nonEmpty ?? "还没有明显匹配到代码线索")
            ]
        )
    }

    private static func apiItems(_ apis: [BackendApi], changes: [FileChange], controlState: UserControlState) -> [TrackableItem] {
        Dictionary(grouping: apis, by: { $0.category.isEmpty ? $0.endpoint.split(separator: "/").first.map(String.init) ?? "接口能力" : $0.category })
            .map { name, group in
                let completed = group.filter(\.completed).count
                let id = "feature:api:\(name)"
                let fingerprint = ProjectBaselineService.fingerprints(from: ActivityData.empty.replacing(backendApis: group))[id]
                return TrackableItem(
                    id: id,
                    title: "\(name.readableTitle())能力",
                    kind: "feature",
                    status: resolvedStatus(for: id, fingerprint: fingerprint, fallback: .baseline, controlState: controlState),
                    confidence: group.count >= 2 && completed == group.count ? .high : .medium,
                    confidenceReason: "识别到 \(group.count) 个相关接口。",
                    businessMeaning: "这块功能已经有后端 API 支撑。",
                    lastTouched: nil,
                    evidence: [
                        Evidence(label: "接口数量", detail: "\(group.count) 个接口，\(completed) 个看起来已完成"),
                        Evidence(label: "代表接口", detail: group.prefix(3).map { "\($0.method.rawValue) \($0.endpoint)" }.joined(separator: "、"))
                    ]
                )
            }
            .sorted { $0.title < $1.title }
    }

    private static func systemItems(_ data: ActivityData) -> [TrackableItem] {
        var items: [TrackableItem] = []
        if !data.databaseTables.isEmpty {
            let id = "feature:database"
            let fingerprint = ProjectBaselineService.fingerprints(from: ActivityData.empty.replacing(databaseTables: data.databaseTables))[id]
            items.append(TrackableItem(id: id, title: "数据存储", kind: "system", status: resolvedStatus(for: id, fingerprint: fingerprint, fallback: .baseline, controlState: data.controlState), confidence: .high, confidenceReason: "扫描到了明确的数据表结构。", businessMeaning: "项目已经有数据表结构，说明业务信息开始被正式保存。", lastTouched: nil, evidence: [Evidence(label: "数据表", detail: "\(data.databaseTables.count) 张表")]))
        }
        if !data.aiLogs.isEmpty || !data.vibeInventory.aiLogic.isEmpty {
            let id = "feature:ai"
            let fingerprint = ProjectBaselineService.fingerprints(from: ActivityData.empty.replacing(aiLogs: data.aiLogs, vibeInventory: data.vibeInventory))[id]
            items.append(TrackableItem(id: id, title: "AI Logic", kind: "system", status: resolvedStatus(for: id, fingerprint: fingerprint, fallback: .baseline, controlState: data.controlState), confidence: .medium, confidenceReason: "扫描到了 AI 相关文件或逻辑名称。", businessMeaning: "项目包含 AI/Agent/Prompt 相关能力。", lastTouched: data.aiLogs.first.map { VibeDateFormatter.display.string(from: $0.timestamp) }, evidence: [Evidence(label: "AI 线索", detail: "\(max(data.aiLogs.count, data.vibeInventory.aiLogic.count)) 条")]))
        }
        if data.vibeHarness.isComplete {
            items.append(TrackableItem(id: "feature:harness", title: "Vibe Harness", kind: "system", status: data.vibeRuleChecks.errors > 0 ? .risk : .done, confidence: .high, confidenceReason: "项目已配置 .vibe harness。", businessMeaning: "认知地图、规则层和 workflow 已经可被追踪。", lastTouched: nil, evidence: [Evidence(label: "规则", detail: "\(data.vibeRuleChecks.rules.count) 条"), Evidence(label: "偏移", detail: "\(data.vibeRuleChecks.checks.count) 个")]))
        }
        return items
    }

    private static func resolvedStatus(for id: String, fingerprint: String?, fallback: ProgressStatus, controlState: UserControlState) -> ProgressStatus {
        if controlState.decisions[id]?.decision == .redo {
            return .redo
        }
        if let fingerprint, ProjectBaselineService.isNewOrChanged(id: id, fingerprint: fingerprint, baseline: controlState.baseline) {
            return .needsReview
        }
        switch controlState.decisions[id]?.decision {
        case .confirmed:
            return .done
        case .redo:
            return .redo
        case .protected, .none:
            return fallback
        }
    }

    private static func controlItems(items: [TrackableItem], data: ActivityData) -> [ControlItem] {
        var controls = items.filter { $0.status == .needsReview || $0.status == .risk || $0.status == .redo }.prefix(10).map {
            ControlItem(id: "control:\($0.id)", title: $0.title, reason: $0.status == .redo ? "你已标记为需要重做" : $0.status == .risk ? "存在需要优先处理的风险" : "扫描到实现线索，请验收是否符合预期", target: $0.id, status: $0.status)
        }
        controls.append(contentsOf: data.vibeRuleChecks.checks.prefix(8).map {
            ControlItem(id: "rule:\($0.id)", title: $0.title, reason: $0.message, target: $0.target, status: $0.severity == .error ? .risk : .needsReview)
        })
        return Array(controls)
    }

    private static func aiWork(_ data: ActivityData) -> [AiWorkItem] {
        var items: [AiWorkItem] = data.aiLogs.prefix(10).map {
            AiWorkItem(id: $0.id, title: $0.action, summary: $0.details, timeAgo: VibeDateFormatter.timeAgo(from: $0.timestamp), evidence: [Evidence(label: "来源", detail: "AI 相关文件扫描")])
        }
        items.append(contentsOf: data.recentCommits.prefix(6).map {
            AiWorkItem(id: "commit:\($0.hash)", title: $0.message, summary: "由 \($0.author) 提交", timeAgo: $0.timeAgo, evidence: [Evidence(label: "提交", detail: $0.shortHash)])
        })
        return items
    }

    private static func requirementEvidence(_ requirement: ProjectRequirement, data: ActivityData) -> [String] {
        let terms = requirement.title.split { $0 == " " || $0 == "," || $0 == "，" || $0 == "/" || $0 == "-" || $0 == "_" }
            .map { $0.lowercased() }
            .filter { $0.count >= 2 }
        var evidence: [String] = []
        for page in data.frontendPages {
            let haystack = "\(page.name) \(page.route) \(page.path) \(page.description)".lowercased()
            if terms.contains(where: { haystack.contains($0) }) { evidence.append("页面 \(page.route.isEmpty ? page.name : page.route)") }
        }
        for api in data.backendApis {
            let haystack = "\(api.name) \(api.endpoint) \(api.description) \(api.category)".lowercased()
            if terms.contains(where: { haystack.contains($0) }) { evidence.append("接口 \(api.method.rawValue) \(api.endpoint)") }
        }
        for commit in data.recentCommits where terms.contains(where: { commit.message.lowercased().contains($0) }) {
            evidence.append("提交 \(commit.shortHash)")
        }
        return evidence.uniqued()
    }

    private static func headline(pages: Int, features: Int, review: Int, risk: Int, goal: String, requirements: Int) -> String {
        if risk > 0 { return "发现 \(risk) 个需要优先确认的风险点" }
        if review > 0 { return "\(review) 个成果需要你验收" }
        if !goal.isEmpty || requirements > 0 { return "正在围绕你的目标追踪 \(pages + features) 个实现线索" }
        return "已识别 \(pages) 个页面和 \(features) 个功能线索"
    }

    private static func nextStep(controls: [ControlItem], pages: Int, features: Int, goal: String) -> String {
        if let first = controls.first { return "先验收：\(first.title)" }
        if goal.isEmpty { return "在控制页写下当前目标，让扫描结果和用户意图对齐。" }
        if pages == 0 && features == 0 { return "生成 .vibe harness 或选择一个包含代码的项目。" }
        return "继续开发后刷新扫描，确认 track.md 与代码没有偏移。"
    }

    private static func aiInstruction(data: ActivityData, controls: [ControlItem], items: [TrackableItem]) -> AiInstruction {
        let top = controls.first?.title ?? items.first?.title ?? "当前任务"
        return AiInstruction(title: "给 AI 的下一步指令", prompt: "请优先处理「\(top)」，完成后更新 .vibe/track.md，并运行最小验证。", source: "根据控制项、规则检查和最近变更自动生成")
    }
}
