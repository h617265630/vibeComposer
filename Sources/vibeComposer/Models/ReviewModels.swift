import SwiftUI

// MARK: - 验收会话

struct ReviewSession: Identifiable, Codable, Hashable {
    let id: String
    let startedAt: Date
    var endedAt: Date?
    var items: [ReviewItem]
    var summary: String?

    var isActive: Bool { endedAt == nil }
    var completedCount: Int { items.filter { $0.decision != nil }.count }
    var totalCount: Int { items.count }
    var progress: Double { totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount) }

    static func start(items: [TrackableItem]) -> ReviewSession {
        ReviewSession(
            id: UUID().uuidString,
            startedAt: Date(),
            endedAt: nil,
            items: items.map { ReviewItem(targetId: $0.id, targetTitle: $0.title, targetKind: $0.kind) },
            summary: nil
        )
    }
}

struct ReviewItem: Identifiable, Codable, Hashable {
    let id: String
    let targetId: String
    let targetTitle: String
    let targetKind: String
    var decision: UserDecision?
    var notes: String?
    var decidedAt: Date?

    init(id: String = UUID().uuidString, targetId: String, targetTitle: String, targetKind: String, decision: UserDecision? = nil, notes: String? = nil, decidedAt: Date? = nil) {
        self.id = id
        self.targetId = targetId
        self.targetTitle = targetTitle
        self.targetKind = targetKind
        self.decision = decision
        self.notes = notes
        self.decidedAt = decidedAt
    }

    var status: ReviewItemStatus {
        if decision == nil { return .pending }
        switch decision {
        case .confirmed: return .accepted
        case .redo: return .rejected
        case .protected: return .skipped
        case .none: return .pending
        }
    }
}

enum ReviewItemStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case skipped

    var label: String {
        switch self {
        case .pending: "待验收"
        case .accepted: "已通过"
        case .rejected: "需重做"
        case .skipped: "已跳过"
        }
    }

    var color: Color {
        switch self {
        case .pending: VibeTheme.amber
        case .accepted: VibeTheme.green
        case .rejected: VibeTheme.red
        case .skipped: .secondary
        }
    }
}

// MARK: - 变更对比

struct DiffReport: Identifiable, Codable, Hashable {
    let id: String
    let since: Date
    let until: Date
    let added: [TrackableItem]
    let modified: [TrackableItem]
    let deleted: [TrackableItem]
    let unchanged: [TrackableItem]

    var hasChanges: Bool { !added.isEmpty || !modified.isEmpty || !deleted.isEmpty }

    var summary: String {
        let parts = [
            added.isEmpty ? nil : "+\(added.count)",
            modified.isEmpty ? nil : "~\(modified.count)",
            deleted.isEmpty ? nil : "-\(deleted.count)"
        ].compactMap { $0 }
        return parts.isEmpty ? "无变更" : parts.joined(separator: " · ")
    }

    var detailedSummary: String {
        var lines: [String] = []
        if !added.isEmpty { lines.append("新增 \(added.count) 项") }
        if !modified.isEmpty { lines.append("修改 \(modified.count) 项") }
        if !deleted.isEmpty { lines.append("删除 \(deleted.count) 项") }
        if !unchanged.isEmpty { lines.append("未变 \(unchanged.count) 项") }
        return lines.isEmpty ? "无数据" : lines.joined(separator: "，")
    }
}

// MARK: - 需求对齐报告

struct AlignmentEvidence: Identifiable, Codable, Hashable {
    var id: String { "\(title)-\(detail)-\(path ?? "")" }
    let title: String
    let detail: String
    let path: String?
}

struct AlignmentReport: Identifiable, Codable, Hashable {
    var id: String { targetId }
    let targetId: String
    let targetTitle: String
    let requirementTitle: String?
    let requirementValue: String?
    let acceptanceCriteria: [String]
    let matchedPages: [AlignmentEvidence]
    let matchedApis: [AlignmentEvidence]
    let matchedTables: [AlignmentEvidence]
    let relatedFiles: [String]
    let missingSignals: [String]
    let riskSignals: [String]
    let recommendation: String

    var hasImplementationEvidence: Bool {
        !matchedPages.isEmpty || !matchedApis.isEmpty || !matchedTables.isEmpty || !relatedFiles.isEmpty
    }
}

// MARK: - Vibe Round

enum VibeRoundStatus: String, Codable, Hashable {
    case active
    case completed

    var label: String {
        switch self {
        case .active: "进行中"
        case .completed: "已完成"
        }
    }
}

struct VibePromptRecord: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: Date
    let prompt: String
    let responseSummary: String
    let model: String
    let source: String
}

struct VibeRound: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var goal: String
    var startedAt: Date
    var endedAt: Date?
    var status: VibeRoundStatus
    var requirementIDs: [String]
    var prompts: [VibePromptRecord]
    var startGenerationCount: Int
    var startBaselineCount: Int
    var acceptedItemIDs: [String]
    var redoItemIDs: [String]
    var verificationPlan: VerificationPlan?

    var promptCount: Int { prompts.count }
}

enum InspectionTargetKind: String, Codable, Hashable {
    case page
    case api
    case database
    case file

    var label: String {
        switch self {
        case .page: "页面"
        case .api: "API"
        case .database: "数据库"
        case .file: "文件"
        }
    }
}

struct InspectionTarget: Identifiable, Codable, Hashable {
    var id: String { "\(kind.rawValue)-\(title)-\(path ?? openURL ?? command ?? "")" }
    let kind: InspectionTargetKind
    let title: String
    let detail: String
    let path: String?
    let openURL: String?
    let command: String?
}

enum VerificationCheckKind: String, Codable, Hashable {
    case command
    case test
    case manual
    case api
    case database

    var label: String {
        switch self {
        case .command: "命令"
        case .test: "测试"
        case .manual: "人工"
        case .api: "API"
        case .database: "数据库"
        }
    }
}

struct VerificationCheck: Identifiable, Codable, Hashable {
    let id: String
    let kind: VerificationCheckKind
    let title: String
    let detail: String
    let command: String?
}

struct VerificationPlan: Identifiable, Codable, Hashable {
    let id: String
    let createdAt: Date
    let checks: [VerificationCheck]
}

// MARK: - 生成记录

enum GenerationKind: String, Codable, CaseIterable {
    case page
    case api
    case database
    case component
    case flow

    var label: String {
        switch self {
        case .page: "页面"
        case .api: "API"
        case .database: "数据库"
        case .component: "组件"
        case .flow: "流程"
        }
    }

    var symbol: String {
        switch self {
        case .page: "rectangle.on.rectangle"
        case .api: "point.3.connected.trianglepath.dotted"
        case .database: "cylinder"
        case .component: "square.stack.3d.up"
        case .flow: "flowchart"
        }
    }
}

enum GenerationStatus: String, Codable {
    case pending
    case reviewing
    case accepted
    case rejected

    var label: String {
        switch self {
        case .pending: "待检查"
        case .reviewing: "检查中"
        case .accepted: "已验收"
        case .rejected: "已拒绝"
        }
    }

    var color: Color {
        switch self {
        case .pending: VibeTheme.amber
        case .reviewing: VibeTheme.accent
        case .accepted: VibeTheme.green
        case .rejected: VibeTheme.red
        }
    }
}

struct GenerationRecord: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: Date
    let kind: GenerationKind
    let title: String
    let description: String
    var sourcePrompt: String?
    let generatedFiles: [String]
    var status: GenerationStatus
    var reviewNotes: String?
    var reviewedAt: Date?

    var timeAgo: String { VibeDateFormatter.timeAgo(from: timestamp) }

    static func create(kind: GenerationKind, title: String, description: String, files: [String], prompt: String? = nil) -> GenerationRecord {
        GenerationRecord(
            id: UUID().uuidString,
            timestamp: Date(),
            kind: kind,
            title: title,
            description: description,
            sourcePrompt: prompt,
            generatedFiles: files,
            status: .pending,
            reviewNotes: nil,
            reviewedAt: nil
        )
    }
}

// MARK: - 时间线

enum TimelineEventKind: String, Codable {
    case generation
    case review
    case acceptance
    case rejection
    case modification
    case sessionStart
    case sessionEnd
    case roundStart
    case roundEnd
    case prompt
    case verification

    var label: String {
        switch self {
        case .generation: "生成"
        case .review: "验收"
        case .acceptance: "通过"
        case .rejection: "拒绝"
        case .modification: "修改"
        case .sessionStart: "开始验收"
        case .sessionEnd: "结束验收"
        case .roundStart: "开始轮次"
        case .roundEnd: "结束轮次"
        case .prompt: "Prompt"
        case .verification: "验证"
        }
    }

    var symbol: String {
        switch self {
        case .generation: "sparkles"
        case .review: "eye"
        case .acceptance: "checkmark.circle"
        case .rejection: "xmark.circle"
        case .modification: "pencil"
        case .sessionStart: "play.circle"
        case .sessionEnd: "stop.circle"
        case .roundStart: "target"
        case .roundEnd: "flag.checkered"
        case .prompt: "text.bubble"
        case .verification: "checklist.checked"
        }
    }

    var color: Color {
        switch self {
        case .generation: VibeTheme.accent
        case .review: VibeTheme.amber
        case .acceptance: VibeTheme.green
        case .rejection: VibeTheme.red
        case .modification: VibeTheme.accent
        case .sessionStart: VibeTheme.accent
        case .sessionEnd: VibeTheme.green
        case .roundStart: VibeTheme.accent
        case .roundEnd: VibeTheme.green
        case .prompt: VibeTheme.accent
        case .verification: VibeTheme.amber
        }
    }
}

struct TimelineEvent: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: Date
    let kind: TimelineEventKind
    let title: String
    let details: String
    let relatedItems: [String]

    var timeAgo: String { VibeDateFormatter.timeAgo(from: timestamp) }

    static func create(kind: TimelineEventKind, title: String, details: String, related: [String] = []) -> TimelineEvent {
        TimelineEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            kind: kind,
            title: title,
            details: details,
            relatedItems: related
        )
    }
}

// MARK: - 扩展 UserControlState

extension UserControlState {
    var reviewSessions: [ReviewSession] {
        get { _reviewSessions }
        set { _reviewSessions = newValue }
    }

    var currentSession: ReviewSession? {
        get { _currentSession }
        set { _currentSession = newValue }
    }

    var generations: [GenerationRecord] {
        get { _generations }
        set { _generations = newValue }
    }

    var timeline: [TimelineEvent] {
        get { _timeline }
        set { _timeline = newValue }
    }

    var currentRound: VibeRound? {
        get { _currentRound }
        set { _currentRound = newValue }
    }

    var rounds: [VibeRound] {
        get { _rounds }
        set { _rounds = newValue }
    }

    // Internal storage
    private var _reviewSessions: [ReviewSession] {
        get { (try? JSONDecoder().decode([ReviewSession].self, from: Data(base64Encoded: reviewSessionsData ?? "") ?? Data())) ?? [] }
        set { reviewSessionsData = try? JSONEncoder().encode(newValue).base64EncodedString() }
    }

    private var _currentSession: ReviewSession? {
        get {
            guard let data = currentSessionData,
                  let decoded = try? JSONDecoder().decode(ReviewSession.self, from: Data(base64Encoded: data) ?? Data())
            else { return nil }
            return decoded
        }
        set { currentSessionData = newValue.flatMap { try? JSONEncoder().encode($0).base64EncodedString() } }
    }

    private var _generations: [GenerationRecord] {
        get { (try? JSONDecoder().decode([GenerationRecord].self, from: Data(base64Encoded: generationsData ?? "") ?? Data())) ?? [] }
        set { generationsData = try? JSONEncoder().encode(newValue).base64EncodedString() }
    }

    private var _timeline: [TimelineEvent] {
        get { (try? JSONDecoder().decode([TimelineEvent].self, from: Data(base64Encoded: timelineData ?? "") ?? Data())) ?? [] }
        set { timelineData = try? JSONEncoder().encode(newValue).base64EncodedString() }
    }

    private var _currentRound: VibeRound? {
        get {
            guard let data = currentRoundData,
                  let decoded = try? JSONDecoder().decode(VibeRound.self, from: Data(base64Encoded: data) ?? Data())
            else { return nil }
            return decoded
        }
        set { currentRoundData = newValue.flatMap { try? JSONEncoder().encode($0).base64EncodedString() } }
    }

    private var _rounds: [VibeRound] {
        get { (try? JSONDecoder().decode([VibeRound].self, from: Data(base64Encoded: roundsData ?? "") ?? Data())) ?? [] }
        set { roundsData = try? JSONEncoder().encode(newValue).base64EncodedString() }
    }

    mutating func addGeneration(_ record: GenerationRecord) {
        var gens = generations
        gens.insert(record, at: 0)
        self.generations = gens

        var tl = timeline
        tl.insert(TimelineEvent.create(kind: .generation, title: "生成 \(record.kind.label)：\(record.title)", details: record.description, related: record.generatedFiles), at: 0)
        self.timeline = tl
    }

    mutating func startReviewSession(items: [TrackableItem]) -> ReviewSession {
        let session = ReviewSession.start(items: items)
        self.currentSession = session

        var tl = timeline
        tl.insert(TimelineEvent.create(kind: .sessionStart, title: "开始验收会话", details: "\(items.count) 项待验收"), at: 0)
        self.timeline = tl

        return session
    }

    mutating func updateCurrentSession(_ update: (inout ReviewSession) -> Void) {
        guard var session = currentSession else { return }
        update(&session)
        self.currentSession = session
    }

    mutating func endCurrentSession(summary: String? = nil) {
        guard var session = currentSession else { return }
        session.endedAt = Date()
        session.summary = summary
        var sessions = reviewSessions
        sessions.insert(session, at: 0)
        self.reviewSessions = sessions
        self.currentSession = nil

        var tl = timeline
        let accepted = session.items.filter { $0.decision == .confirmed }.count
        let rejected = session.items.filter { $0.decision == .redo }.count
        tl.insert(TimelineEvent.create(kind: .sessionEnd, title: "结束验收会话", details: "通过 \(accepted) 项，拒绝 \(rejected) 项"), at: 0)
        self.timeline = tl
    }
}
