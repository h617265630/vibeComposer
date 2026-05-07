import SwiftUI

enum ReviewService {
    /// 获取待验收的项目
    static func itemsNeedingReview(from data: ActivityData) -> [TrackableItem] {
        let progress = ProgressDeriver.derive(from: data)
        return (progress.pages + progress.features).filter { item in
            item.status == .needsReview || item.status == .risk || item.status == .inProgress
        }
    }

    /// 开始新的验收会话
    static func startReviewSession(in state: inout UserControlState, items: [TrackableItem]) -> ReviewSession {
        state.startReviewSession(items: items)
        return state.currentSession!
    }

    /// 验收单个项目
    static func reviewItem(in state: inout UserControlState, itemId: String, decision: UserDecision, notes: String? = nil) {
        state.updateCurrentSession { session in
            if let index = session.items.firstIndex(where: { $0.id == itemId }) {
                session.items[index].decision = decision
                session.items[index].notes = notes
                session.items[index].decidedAt = Date()
            }
        }

        // 同时更新 decisions
        if let session = state.currentSession,
           let item = session.items.first(where: { $0.id == itemId }) {
            state.decisions[item.targetId] = UserControlDecision(decision: decision, updatedAt: Date())
        }

        // 添加时间线事件
        var tl = state.timeline
        let eventKind: TimelineEventKind = decision == .confirmed ? .acceptance : .rejection
        if let session = state.currentSession,
           let item = session.items.first(where: { $0.id == itemId }) {
            tl.insert(TimelineEvent.create(
                kind: eventKind,
                title: "\(decision == .confirmed ? "通过" : "拒绝")：\(item.targetTitle)",
                details: notes ?? "",
                related: [item.targetId]
            ), at: 0)
        }
        state.timeline = tl
    }

    /// 结束验收会话
    static func endReviewSession(in state: inout UserControlState, summary: String? = nil) {
        state.endCurrentSession(summary: summary)
    }

    /// 获取验收统计
    static func reviewStats(from state: UserControlState) -> ReviewStats {
        let sessions = state.reviewSessions
        let totalSessions = sessions.count
        let totalItems = sessions.reduce(0) { $0 + $1.items.count }
        let acceptedItems = sessions.reduce(0) { sum, session in
            sum + session.items.filter { $0.decision == .confirmed }.count
        }
        let rejectedItems = sessions.reduce(0) { sum, session in
            sum + session.items.filter { $0.decision == .redo }.count
        }

        return ReviewStats(
            totalSessions: totalSessions,
            totalItems: totalItems,
            acceptedItems: acceptedItems,
            rejectedItems: rejectedItems,
            averageSessionSize: totalSessions > 0 ? Double(totalItems) / Double(totalSessions) : 0
        )
    }

    /// 生成对齐报告
    static func alignmentReport(for item: TrackableItem, in data: ActivityData) -> AlignmentReport {
        // 尝试找到关联的需求
        let requirement = data.controlState.requirements.first { req in
            item.id.contains(req.id) || item.title.lowercased().contains(req.title.lowercased())
        }

        return AlignmentService.analyzeAlignment(
            requirement: requirement ?? ProjectRequirement(
                id: item.id,
                title: item.title,
                userValue: item.businessMeaning,
                acceptanceCriteria: [],
                priority: .medium,
                status: .needsReview,
                updatedAt: Date()
            ),
            data: data
        )
    }

    /// 生成重做 prompt
    static func redoPrompt(for item: TrackableItem, report: AlignmentReport, notes: String? = nil) -> String {
        let notesSection = notes.map { "\n用户备注：\($0)" } ?? ""
        return """
        请重做以下实现项：

        标题：\(item.title)
        类型：\(item.kind)
        业务含义：\(item.businessMeaning)

        当前实现线索：
        - 页面：\(report.matchedPages.map { $0.title }.joined(separator: "、"))
        - API：\(report.matchedApis.map { $0.title }.joined(separator: "、"))
        - 数据库：\(report.matchedTables.map { $0.title }.joined(separator: "、"))

        缺失信号：
        \(report.missingSignals.map { "- \($0)" }.joined(separator: "\n"))

        风险信号：
        \(report.riskSignals.map { "- \($0)" }.joined(separator: "\n"))
        \(notesSection)

        请给出最小修改方案，确保满足业务需求。
        """
    }

    /// 扫描后同步控制状态
    static func controlStateAfterScan(_ data: ActivityData, previousState: UserControlState) -> UserControlState {
        var state = previousState

        // 推断新的生成记录
        let existingPaths = Set(state.generations.flatMap { $0.generatedFiles })
        let newRecords = inferNewGenerations(from: data, existingPaths: existingPaths)

        if !newRecords.isEmpty {
            var gens = state.generations
            for record in newRecords {
                gens.insert(record, at: 0)
            }
            state.generations = gens
        }

        return state
    }

    /// 推断新的生成记录
    private static func inferNewGenerations(from data: ActivityData, existingPaths: Set<String>) -> [GenerationRecord] {
        var records: [GenerationRecord] = []

        for page in data.frontendPages {
            if !existingPaths.contains(page.path) {
                records.append(GenerationRecord.create(
                    kind: .page,
                    title: page.name,
                    description: page.route.isEmpty ? page.path : page.route,
                    files: [page.path]
                ))
            }
        }

        for api in data.backendApis {
            let apiId = "\(api.method.rawValue) \(api.endpoint)"
            if !existingPaths.contains(apiId) && !existingPaths.contains(api.path) {
                records.append(GenerationRecord.create(
                    kind: .api,
                    title: api.name,
                    description: "\(api.method.rawValue) \(api.endpoint)",
                    files: [api.path]
                ))
            }
        }

        for table in data.databaseTables {
            if !existingPaths.contains(table.name) {
                records.append(GenerationRecord.create(
                    kind: .database,
                    title: table.name,
                    description: "\(table.columns.count) 字段",
                    files: []
                ))
            }
        }

        return records
    }
}

struct ReviewStats {
    let totalSessions: Int
    let totalItems: Int
    let acceptedItems: Int
    let rejectedItems: Int
    let averageSessionSize: Double

    var acceptanceRate: Double {
        totalItems > 0 ? Double(acceptedItems) / Double(totalItems) * 100 : 0
    }
}

// MARK: - 变更追踪服务

enum DiffTracker {
    /// 计算自上次验收以来的变更
    static func computeDiff(since baseline: ProjectBaseline?, current: ActivityData) -> DiffReport {
        guard let baseline else {
            let progress = ProgressDeriver.derive(from: current)
            let allItems = progress.pages + progress.features
            return DiffReport(
                id: UUID().uuidString,
                since: Date.distantPast,
                until: Date(),
                added: allItems,
                modified: [],
                deleted: [],
                unchanged: []
            )
        }

        let progress = ProgressDeriver.derive(from: current)
        let allItems = progress.pages + progress.features
        let currentFingerprints = ProjectBaselineService.fingerprints(from: current)

        var added: [TrackableItem] = []
        var modified: [TrackableItem] = []
        var unchanged: [TrackableItem] = []

        for item in allItems {
            if let currentFp = currentFingerprints[item.id] {
                if let baselineFp = baseline.itemFingerprints[item.id] {
                    if currentFp == baselineFp {
                        unchanged.append(item)
                    } else {
                        modified.append(item)
                    }
                } else {
                    added.append(item)
                }
            } else {
                added.append(item)
            }
        }

        var deleted: [TrackableItem] = []
        for (id, _) in baseline.itemFingerprints {
            if currentFingerprints[id] == nil {
                deleted.append(TrackableItem(
                    id: id,
                    title: id.components(separatedBy: ":").last ?? id,
                    kind: id.hasPrefix("page:") ? "page" : "feature",
                    status: .redo,
                    confidence: .low,
                    confidenceReason: "此项目在基线中存在但当前扫描未找到",
                    businessMeaning: "可能已被删除或移动",
                    lastTouched: nil,
                    evidence: []
                ))
            }
        }

        return DiffReport(
            id: UUID().uuidString,
            since: baseline.createdAt,
            until: Date(),
            added: added,
            modified: modified,
            deleted: deleted,
            unchanged: unchanged
        )
    }

    /// 创建新的基线
    static func createBaseline(from data: ActivityData) -> ProjectBaseline {
        ProjectBaseline(
            createdAt: Date(),
            itemFingerprints: ProjectBaselineService.fingerprints(from: data)
        )
    }

    /// 更新基线（验收通过后调用）
    static func updateBaseline(_ baseline: ProjectBaseline?, with data: ActivityData, acceptedIDs: [String]) -> ProjectBaseline {
        let newBaseline = baseline ?? createBaseline(from: data)
        var newFingerprints = newBaseline.itemFingerprints
        let currentFingerprints = ProjectBaselineService.fingerprints(from: data)

        for id in acceptedIDs {
            if let fp = currentFingerprints[id] {
                newFingerprints[id] = fp
            }
        }

        return ProjectBaseline(
            createdAt: newBaseline.createdAt,
            itemFingerprints: newFingerprints
        )
    }
}
