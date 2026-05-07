import SwiftUI

// MARK: - LLM 生成记录服务

enum GenerationRecordService {
    /// 从当前扫描推断生成记录
    static func inferGenerations(from data: ActivityData, existing: [GenerationRecord]) -> [GenerationRecord] {
        var records = existing
        let existingIds = Set(existing.flatMap { $0.generatedFiles })

        // 检查新页面
        for page in data.frontendPages {
            if !existingIds.contains(page.path) {
                let record = GenerationRecord.create(
                    kind: .page,
                    title: page.name,
                    description: page.route.isEmpty ? "页面路径: \(page.path)" : "路由: \(page.route)",
                    files: [page.path]
                )
                records.insert(record, at: 0)
            }
        }

        // 检查新 API
        for api in data.backendApis {
            let apiId = "\(api.method.rawValue) \(api.endpoint)"
            if !existingIds.contains(apiId) {
                let record = GenerationRecord.create(
                    kind: .api,
                    title: api.name,
                    description: "\(api.method.rawValue) \(api.endpoint)",
                    files: [api.path]
                )
                records.insert(record, at: 0)
            }
        }

        // 检查新数据表
        for table in data.databaseTables {
            if !existingIds.contains(table.name) {
                let record = GenerationRecord.create(
                    kind: .database,
                    title: table.name,
                    description: "数据表，\(table.columns.count) 个字段",
                    files: []
                )
                records.insert(record, at: 0)
            }
        }

        return records
    }

    /// 更新生成记录状态
    static func updateStatus(_ records: inout [GenerationRecord], id: String, status: GenerationStatus, notes: String? = nil) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].status = status
            records[index].reviewNotes = notes
            records[index].reviewedAt = Date()
        }
    }

    /// 创建手动生成记录
    static func createManualRecord(
        kind: GenerationKind,
        title: String,
        description: String,
        files: [String],
        prompt: String?,
        responseSummary: String?
    ) -> GenerationRecord {
        var record = GenerationRecord.create(
            kind: kind,
            title: title,
            description: description,
            files: files,
            prompt: prompt
        )
        // 如果有响应摘要，添加到描述中
        if let summary = responseSummary, !summary.isEmpty {
            record = GenerationRecord(
                id: record.id,
                timestamp: record.timestamp,
                kind: record.kind,
                title: record.title,
                description: "\(record.description)\n\n响应摘要: \(summary)",
                sourcePrompt: record.sourcePrompt,
                generatedFiles: record.generatedFiles,
                status: record.status,
                reviewNotes: record.reviewNotes,
                reviewedAt: record.reviewedAt
            )
        }
        return record
    }
}

// MARK: - 需求对齐分析服务

enum AlignmentService {
    /// 分析需求与实现的匹配度
    static func analyzeAlignment(
        requirement: ProjectRequirement,
        data: ActivityData
    ) -> AlignmentReport {
        let terms = extractKeywords(from: requirement.title)

        var matchedPages: [AlignmentEvidence] = []
        var matchedApis: [AlignmentEvidence] = []
        var matchedTables: [AlignmentEvidence] = []
        var relatedFiles: [String] = []
        var missingSignals: [String] = []
        var riskSignals: [String] = []

        // 分析页面匹配
        for page in data.frontendPages {
            let score = matchScore(terms: terms, text: "\(page.name) \(page.route) \(page.path) \(page.description)")
            if score > 0 {
                matchedPages.append(AlignmentEvidence(
                    title: page.name,
                    detail: page.route.isEmpty ? page.path : page.route,
                    path: page.path
                ))
                relatedFiles.append(page.path)
            }
        }

        // 分析 API 匹配
        for api in data.backendApis {
            let score = matchScore(terms: terms, text: "\(api.name) \(api.endpoint) \(api.description) \(api.category)")
            if score > 0 {
                matchedApis.append(AlignmentEvidence(
                    title: "\(api.method.rawValue) \(api.endpoint)",
                    detail: api.name,
                    path: api.path
                ))
                relatedFiles.append(api.path)
            }
        }

        // 分析数据库匹配
        for table in data.databaseTables {
            let score = matchScore(terms: terms, text: "\(table.name) \(table.columns.map { $0.name }.joined(separator: " "))")
            if score > 0 {
                matchedTables.append(AlignmentEvidence(
                    title: table.name,
                    detail: "\(table.columns.count) 字段",
                    path: nil
                ))
            }
        }

        // 检查缺失信号
        if matchedPages.isEmpty {
            missingSignals.append("未找到匹配的页面实现")
        }
        if matchedApis.isEmpty {
            missingSignals.append("未找到匹配的 API 接口")
        }
        if matchedTables.isEmpty && requirement.title.contains("数据") || requirement.title.contains("存储") {
            missingSignals.append("未找到匹配的数据表")
        }

        // 检查风险信号
        if !requirement.acceptanceCriteria.isEmpty {
            if matchedPages.isEmpty && matchedApis.isEmpty {
                riskSignals.append("需求有验收标准但未找到实现线索")
            }
        }

        // 生成建议
        let recommendation = generateRecommendation(
            matchedPages: matchedPages,
            matchedApis: matchedApis,
            matchedTables: matchedTables,
            missingSignals: missingSignals,
            riskSignals: riskSignals
        )

        return AlignmentReport(
            targetId: "requirement:\(requirement.id)",
            targetTitle: requirement.title,
            requirementTitle: requirement.title,
            requirementValue: requirement.userValue,
            acceptanceCriteria: requirement.acceptanceCriteria,
            matchedPages: matchedPages,
            matchedApis: matchedApis,
            matchedTables: matchedTables,
            relatedFiles: relatedFiles,
            missingSignals: missingSignals,
            riskSignals: riskSignals,
            recommendation: recommendation
        )
    }

    /// 批量分析所有需求
    static func analyzeAllRequirements(data: ActivityData) -> [AlignmentReport] {
        data.controlState.requirements.map { analyzeAlignment(requirement: $0, data: data) }
    }

    /// 提取关键词
    private static func extractKeywords(from text: String) -> [String] {
        text.split { $0 == " " || $0 == "," || $0 == "，" || $0 == "/" || $0 == "-" || $0 == "_" }
            .map { $0.lowercased() }
            .filter { $0.count >= 2 }
    }

    /// 计算匹配分数
    private static func matchScore(terms: [String], text: String) -> Int {
        let lowerText = text.lowercased()
        return terms.filter { lowerText.contains($0) }.count
    }

    /// 生成建议
    private static func generateRecommendation(
        matchedPages: [AlignmentEvidence],
        matchedApis: [AlignmentEvidence],
        matchedTables: [AlignmentEvidence],
        missingSignals: [String],
        riskSignals: [String]
    ) -> String {
        if matchedPages.isEmpty && matchedApis.isEmpty && matchedTables.isEmpty {
            return "未找到实现线索，建议先实现此需求"
        }

        if !riskSignals.isEmpty {
            return "存在风险：\(riskSignals.joined(separator: "；"))"
        }

        let parts: [String] = [
            !matchedPages.isEmpty ? "找到 \(matchedPages.count) 个相关页面" : nil,
            !matchedApis.isEmpty ? "找到 \(matchedApis.count) 个相关 API" : nil,
            !matchedTables.isEmpty ? "找到 \(matchedTables.count) 个相关数据表" : nil
        ].compactMap { $0 }

        return parts.isEmpty ? "需要人工确认" : parts.joined(separator: "，")
    }
}

// MARK: - 轮次管理服务

enum RoundService {
    /// 开始新轮次
    static func startRound(in state: inout UserControlState, title: String, goal: String) -> VibeRound {
        let round = VibeRound(
            id: UUID().uuidString,
            title: title.isEmpty ? "Vibe 轮次" : title,
            goal: goal,
            startedAt: Date(),
            endedAt: nil,
            status: .active,
            requirementIDs: state.requirements.map { $0.id },
            prompts: [],
            startGenerationCount: state.generations.count,
            startBaselineCount: state.baseline?.itemFingerprints.count ?? 0,
            acceptedItemIDs: [],
            redoItemIDs: [],
            verificationPlan: nil
        )
        state.currentRound = round

        var tl = state.timeline
        tl.insert(TimelineEvent.create(kind: .roundStart, title: "开始轮次：\(round.title)", details: goal), at: 0)
        state.timeline = tl

        return round
    }

    /// 记录 Prompt
    static func recordPrompt(
        in state: inout UserControlState,
        prompt: String,
        responseSummary: String,
        model: String,
        source: String
    ) -> VibePromptRecord {
        let record = VibePromptRecord(
            id: UUID().uuidString,
            timestamp: Date(),
            prompt: prompt,
            responseSummary: responseSummary,
            model: model,
            source: source
        )

        if var round = state.currentRound {
            round.prompts.insert(record, at: 0)
            state.currentRound = round
        }

        var tl = state.timeline
        tl.insert(TimelineEvent.create(kind: .prompt, title: "记录 Prompt", details: prompt.prefix(100) + (prompt.count > 100 ? "..." : "")), at: 0)
        state.timeline = tl

        return record
    }

    /// 结束轮次
    static func endRound(in state: inout UserControlState) {
        guard var round = state.currentRound else { return }

        round.status = .completed
        round.endedAt = Date()
        round.acceptedItemIDs = state.decisions
            .filter { $0.value.decision == .confirmed }
            .map { $0.key }
        round.redoItemIDs = state.decisions
            .filter { $0.value.decision == .redo }
            .map { $0.key }

        var rounds = state.rounds
        rounds.insert(round, at: 0)
        state.rounds = rounds
        state.currentRound = nil

        var tl = state.timeline
        tl.insert(TimelineEvent.create(
            kind: .roundEnd,
            title: "结束轮次：\(round.title)",
            details: "通过 \(round.acceptedItemIDs.count) 项，重做 \(round.redoItemIDs.count) 项"
        ), at: 0)
        state.timeline = tl
    }

    /// 获取轮次统计
    static func roundStats(rounds: [VibeRound]) -> RoundStats {
        let total = rounds.count
        let totalPrompts = rounds.reduce(0) { $0 + $1.prompts.count }
        let totalAccepted = rounds.reduce(0) { $0 + $1.acceptedItemIDs.count }
        let totalRedo = rounds.reduce(0) { $0 + $1.redoItemIDs.count }

        return RoundStats(
            totalRounds: total,
            totalPrompts: totalPrompts,
            totalAccepted: totalAccepted,
            totalRedo: totalRedo
        )
    }
}

struct RoundStats {
    let totalRounds: Int
    let totalPrompts: Int
    let totalAccepted: Int
    let totalRedo: Int
}
