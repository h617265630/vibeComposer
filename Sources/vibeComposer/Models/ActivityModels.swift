import Foundation

struct GitCommit: Identifiable, Codable, Hashable {
    var id: String { hash }
    let hash: String
    let shortHash: String
    let message: String
    let author: String
    let date: Date
    let timeAgo: String
}

enum FileChangeType: String, Codable, Hashable {
    case modified
    case created
    case deleted

    var label: String {
        switch self {
        case .modified: "修改"
        case .created: "新增"
        case .deleted: "删除"
        }
    }
}

struct FileChange: Identifiable, Codable, Hashable {
    var id: String { "\(relativePath)-\(timestamp.timeIntervalSince1970)-\(type.rawValue)" }
    let type: FileChangeType
    let path: String
    let relativePath: String
    let timestamp: Date
    let fileExtension: String
}

enum TreeNodeType: String, Codable, Hashable {
    case file
    case folder
}

struct TreeNode: Identifiable, Codable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let type: TreeNodeType
    let children: [TreeNode]
    let depth: Int
}

struct TechStackItem: Identifiable, Codable, Hashable {
    var id: String { "\(name)-\(version ?? "")-\(description ?? "")" }
    let name: String
    let version: String?
    let description: String?
}

struct TechStack: Identifiable, Codable, Hashable {
    var id: String { category }
    let category: String
    let items: [TechStackItem]
}

enum TodoPriority: String, Codable, Hashable {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        }
    }
}

struct TodoTask: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let completed: Bool
    let priority: TodoPriority
}

enum ImportedModuleType: String, Codable, Hashable {
    case local
    case npm
    case relative
}

struct ImportedModule: Identifiable, Codable, Hashable {
    var id: String { "\(path)-\(name)" }
    let name: String
    let path: String
    let type: ImportedModuleType
    let isComponent: Bool
}

struct SharedComponent: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let path: String
    let usageCount: Int
    let usedInPages: [String]
}

struct FrontendPage: Identifiable, Codable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let route: String
    let category: String
    let description: String
    let tasks: [TodoTask]
    let componentCount: Int
    let modules: [ImportedModule]
    let sharedComponents: [String]
    let localComponents: [String]
    let hooksUsed: [String]
    let fileSize: Int
    let lastModified: Date?
}

struct NamedCount: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let count: Int
}

struct FrontendScanResult: Codable, Hashable {
    let pages: [FrontendPage]
    let sharedComponents: [SharedComponent]
    let categories: [NamedCount]
    let totalComponents: Int
    let totalHooks: Int
}

enum HttpMethod: String, Codable, Hashable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case options = "OPTIONS"
    case head = "HEAD"
}

struct BackendApi: Identifiable, Codable, Hashable {
    var id: String { "\(method.rawValue) \(endpoint)" }
    let name: String
    let path: String
    let method: HttpMethod
    let endpoint: String
    let description: String
    let category: String
    let completed: Bool
    let responseFields: Int
}

struct FlowStep: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let completed: Bool
    let details: String?
}

struct BackendFlow: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let steps: [FlowStep]
    let completedPercent: Int
}

struct TableColumn: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let type: String
    let nullable: Bool
    let primaryKey: Bool
    let `default`: String?
}

struct TableRelation: Identifiable, Codable, Hashable {
    var id: String { "\(fromColumn)-\(toTable)-\(toColumn)" }
    let fromColumn: String
    let toTable: String
    let toColumn: String
    let type: String
}

struct DatabaseTable: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    var columns: [TableColumn]
    var relations: [TableRelation]
}

struct AILog: Identifiable, Codable, Hashable {
    var id: String { "\(timestamp.timeIntervalSince1970)-\(action)-\(details)" }
    let timestamp: Date
    let action: String
    let details: String
}

struct UnitTestFile: Identifiable, Codable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let framework: String
    let testCount: Int
    let lastModified: Date?
}

struct UnitTestSummary: Codable, Hashable {
    let files: [UnitTestFile]
    let frameworks: [String]
    let totalTests: Int
    let hasCoverage: Bool
}

struct LinterConfig: Identifiable, Codable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let type: String
    let rules: [String]
}

struct CodeStandards: Codable, Hashable {
    let linters: [LinterConfig]
    let formatters: [LinterConfig]
    let hasStrictMode: Bool
    let typeSafetyConfigPath: String?
    let isConfigured: Bool
}

struct UIToken: Identifiable, Codable, Hashable {
    var id: String { "\(type)-\(name)-\(value)" }
    let name: String
    let value: String
    let type: String
}

struct UIStandards: Codable, Hashable {
    let cssFramework: String
    let configPath: String?
    let tokens: [UIToken]
    let componentLibs: [String]
    let isConfigured: Bool
}

enum CodeQualitySeverity: String, Codable, Hashable {
    case info
    case warning
    case error

    var label: String {
        switch self {
        case .info: "提示"
        case .warning: "警告"
        case .error: "错误"
        }
    }
}

struct CodeQualityCheck: Identifiable, Codable, Hashable {
    var id: String { "\(file)-\(line ?? 0)-\(message)" }
    let category: String
    let file: String
    let line: Int?
    let severity: CodeQualitySeverity
    let message: String
    let suggestion: String?
}

struct CodeQualitySummary: Codable, Hashable {
    let total: Int
    let byCategory: [NamedCount]
    let bySeverity: [NamedCount]
    let score: Int
}

struct CodeQualityReport: Codable, Hashable {
    let checks: [CodeQualityCheck]
    let summary: CodeQualitySummary
}

enum ProjectRequirementStatus: String, Codable, Hashable, CaseIterable {
    case planned
    case inProgress = "in-progress"
    case needsReview = "needs-review"
    case done
    case redo

    var label: String {
        switch self {
        case .planned: "计划中"
        case .inProgress: "进行中"
        case .needsReview: "需验收"
        case .done: "完成"
        case .redo: "重做"
        }
    }
}

enum ProjectRequirementPriority: String, Codable, Hashable, CaseIterable {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        }
    }
}

struct ProjectRequirement: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var userValue: String
    var acceptanceCriteria: [String]
    var priority: ProjectRequirementPriority
    var status: ProjectRequirementStatus
    var updatedAt: Date
}

struct ProjectBaseline: Codable, Hashable {
    var createdAt: Date
    var itemFingerprints: [String: String]
}

enum UserDecision: String, Codable, Hashable {
    case confirmed
    case redo
    case protected
}

struct UserControlDecision: Codable, Hashable {
    var decision: UserDecision
    var updatedAt: Date
}

struct UserControlState: Codable, Hashable {
    var goal: String
    var requirements: [ProjectRequirement]
    var protectedPaths: [String]
    var decisions: [String: UserControlDecision]
    var baseline: ProjectBaseline?

    // 新增：验收会话和生成记录的存储
    var reviewSessionsData: String?
    var currentSessionData: String?
    var generationsData: String?
    var timelineData: String?
    var currentRoundData: String?
    var roundsData: String?
    var previewBaseURL: String
    var verificationCommand: String

    static let empty = UserControlState(goal: "", requirements: [], protectedPaths: [], decisions: [:], baseline: nil, reviewSessionsData: nil, currentSessionData: nil, generationsData: nil, timelineData: nil, currentRoundData: nil, roundsData: nil, previewBaseURL: "", verificationCommand: "")

    enum CodingKeys: String, CodingKey {
        case goal
        case requirements
        case protectedPaths
        case decisions
        case baseline
        case reviewSessionsData
        case currentSessionData
        case generationsData
        case timelineData
        case currentRoundData
        case roundsData
        case previewBaseURL
        case verificationCommand
    }

    init(goal: String, requirements: [ProjectRequirement], protectedPaths: [String], decisions: [String: UserControlDecision], baseline: ProjectBaseline? = nil, reviewSessionsData: String? = nil, currentSessionData: String? = nil, generationsData: String? = nil, timelineData: String? = nil, currentRoundData: String? = nil, roundsData: String? = nil, previewBaseURL: String = "", verificationCommand: String = "") {
        self.goal = goal
        self.requirements = requirements
        self.protectedPaths = protectedPaths
        self.decisions = decisions
        self.baseline = baseline
        self.reviewSessionsData = reviewSessionsData
        self.currentSessionData = currentSessionData
        self.generationsData = generationsData
        self.timelineData = timelineData
        self.currentRoundData = currentRoundData
        self.roundsData = roundsData
        self.previewBaseURL = previewBaseURL
        self.verificationCommand = verificationCommand
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        requirements = try container.decodeIfPresent([ProjectRequirement].self, forKey: .requirements) ?? []
        protectedPaths = try container.decodeIfPresent([String].self, forKey: .protectedPaths) ?? []
        decisions = try container.decodeIfPresent([String: UserControlDecision].self, forKey: .decisions) ?? [:]
        baseline = try container.decodeIfPresent(ProjectBaseline.self, forKey: .baseline)
        reviewSessionsData = try container.decodeIfPresent(String.self, forKey: .reviewSessionsData)
        currentSessionData = try container.decodeIfPresent(String.self, forKey: .currentSessionData)
        generationsData = try container.decodeIfPresent(String.self, forKey: .generationsData)
        timelineData = try container.decodeIfPresent(String.self, forKey: .timelineData)
        currentRoundData = try container.decodeIfPresent(String.self, forKey: .currentRoundData)
        roundsData = try container.decodeIfPresent(String.self, forKey: .roundsData)
        previewBaseURL = try container.decodeIfPresent(String.self, forKey: .previewBaseURL) ?? ""
        verificationCommand = try container.decodeIfPresent(String.self, forKey: .verificationCommand) ?? ""
    }
}

struct VibeHarnessStatus: Codable, Hashable {
    let isComplete: Bool
    let missingFiles: [String]
    let requiredFiles: [String: Bool]
}

enum VibeRuleSeverity: String, Codable, Hashable {
    case info
    case warning
    case error
}

struct VibeRuleCheck: Identifiable, Codable, Hashable {
    let id: String
    let severity: VibeRuleSeverity
    let title: String
    let message: String
    let rule: String
    let target: String
}

struct VibeRuleCheckReport: Codable, Hashable {
    let isConfigured: Bool
    let rules: [String]
    let checks: [VibeRuleCheck]
    let errors: Int
    let warnings: Int
    let info: Int
}

enum VibeWorkflowStepStatus: String, Codable, Hashable {
    case done
    case active
    case blocked
    case pending

    var label: String {
        switch self {
        case .done: "完成"
        case .active: "进行中"
        case .blocked: "阻塞"
        case .pending: "等待"
        }
    }
}

struct VibeWorkflowStep: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let status: VibeWorkflowStepStatus
    let reason: String
}

struct VibeWorkflowReport: Codable, Hashable {
    let isConfigured: Bool
    let title: String
    let currentTask: String
    let steps: [VibeWorkflowStep]
    let done: Int
    let active: Int
    let blocked: Int
    let pending: Int
}

struct VibeProjectInventory: Codable, Hashable {
    let projectName: String
    let frontendPages: [String]
    let backendApis: [String]
    let databaseTables: [String]
    let aiLogic: [String]
    // 新增：Apple 项目和通用项目信息
    var appleProject: AppleProjectInfo?
    var genericProject: GenericProjectInfo?
    var projectType: String
}

struct TodayStats: Codable, Hashable {
    let commits: Int
    let filesChanged: Int
    let insertions: Int
    let deletions: Int

    static let empty = TodayStats(commits: 0, filesChanged: 0, insertions: 0, deletions: 0)
}

struct ActivityData: Codable, Hashable {
    var recentCommits: [GitCommit]
    var todayCommits: [GitCommit]
    var todayStats: TodayStats
    var recentChanges: [FileChange]
    var projectStructure: [TreeNode]
    var techStack: [TechStack]
    var frontendPages: [FrontendPage]
    var frontendScan: FrontendScanResult
    var backendApis: [BackendApi]
    var backendFlows: [BackendFlow]
    var databaseTables: [DatabaseTable]
    var aiLogs: [AILog]
    var unitTests: UnitTestSummary
    var codeStandards: CodeStandards
    var uiStandards: UIStandards
    var codeQuality: CodeQualityReport
    var controlState: UserControlState
    var vibeHarness: VibeHarnessStatus
    var vibeRuleChecks: VibeRuleCheckReport
    var vibeWorkflow: VibeWorkflowReport
    var vibeInventory: VibeProjectInventory

    static let empty = ActivityData(
        recentCommits: [],
        todayCommits: [],
        todayStats: .empty,
        recentChanges: [],
        projectStructure: [],
        techStack: [],
        frontendPages: [],
        frontendScan: FrontendScanResult(pages: [], sharedComponents: [], categories: [], totalComponents: 0, totalHooks: 0),
        backendApis: [],
        backendFlows: [],
        databaseTables: [],
        aiLogs: [],
        unitTests: UnitTestSummary(files: [], frameworks: [], totalTests: 0, hasCoverage: false),
        codeStandards: CodeStandards(linters: [], formatters: [], hasStrictMode: false, typeSafetyConfigPath: nil, isConfigured: false),
        uiStandards: UIStandards(cssFramework: "none", configPath: nil, tokens: [], componentLibs: [], isConfigured: false),
        codeQuality: CodeQualityReport(checks: [], summary: CodeQualitySummary(total: 0, byCategory: [], bySeverity: [], score: 100)),
        controlState: .empty,
        vibeHarness: VibeHarnessStatus(isComplete: false, missingFiles: ["track.md", "rules.md", "workflow.md"], requiredFiles: ["track.md": false, "rules.md": false, "workflow.md": false]),
        vibeRuleChecks: VibeRuleCheckReport(isConfigured: false, rules: [], checks: [], errors: 0, warnings: 0, info: 0),
        vibeWorkflow: VibeWorkflowReport(isConfigured: false, title: "Harness Workflow", currentTask: "未配置 workflow.md", steps: [], done: 0, active: 0, blocked: 0, pending: 0),
        vibeInventory: VibeProjectInventory(projectName: "", frontendPages: [], backendApis: [], databaseTables: [], aiLogic: [], appleProject: nil, genericProject: nil, projectType: "Unknown")
    )

    // MARK: - Replacing helpers

    func replacing(frontendPages: [FrontendPage]) -> ActivityData {
        var copy = self
        copy.frontendPages = frontendPages
        return copy
    }

    func replacing(backendApis: [BackendApi]) -> ActivityData {
        var copy = self
        copy.backendApis = backendApis
        return copy
    }

    func replacing(databaseTables: [DatabaseTable]) -> ActivityData {
        var copy = self
        copy.databaseTables = databaseTables
        return copy
    }

    func replacing(aiLogs: [AILog], vibeInventory: VibeProjectInventory) -> ActivityData {
        var copy = self
        copy.aiLogs = aiLogs
        copy.vibeInventory = vibeInventory
        return copy
    }
}
