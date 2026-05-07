import Foundation

// MARK: - Claude Code 会话解析服务

enum ClaudeCodeSessionService {

    /// Claude Code 会话目录
    static var claudeProjectsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    /// Codex 日志数据库
    static var codexLogsDB: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/logs_2.sqlite")
    }

    /// 获取项目对应的 Claude Code 会话目录
    static func getSessionDir(for projectPath: String) -> URL? {
        // 将路径转换为 Claude Code 的项目目录名格式
        // 例如: /Users/burn/Code/vibeComposer -> -Users-burn-Code-vibeComposer
        let normalizedPath = projectPath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

        let sessionDir = claudeProjectsDir.appendingPathComponent(normalizedPath)
        if FileManager.default.fileExistsAndIsDirectory(at: sessionDir) {
            return sessionDir
        }

        // 尝试其他可能的格式
        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        if let dirs = try? FileManager.default.contentsOfDirectory(at: claudeProjectsDir, includingPropertiesForKeys: nil) {
            for dir in dirs {
                if dir.lastPathComponent.contains(projectName) {
                    return dir
                }
            }
        }

        return nil
    }

    /// 读取项目的所有会话
    static func readSessions(for projectPath: String) -> [ClaudeSession] {
        guard let sessionDir = getSessionDir(for: projectPath) else { return [] }

        var sessions: [ClaudeSession] = []

        // 读取所有 .jsonl 文件
        guard let files = try? FileManager.default.contentsOfDirectory(at: sessionDir, includingPropertiesForKeys: nil) else { return [] }

        for file in files where file.pathExtension == "jsonl" {
            let sessionId = file.deletingPathExtension().lastPathComponent
            let events = parseSessionFile(file)

            if !events.isEmpty {
                // 提取会话摘要
                let summary = extractSessionSummary(events: events, sessionId: sessionId)
                sessions.append(summary)
            }
        }

        // 按时间排序，最新的在前
        return sessions.sorted { $0.lastActivity > $1.lastActivity }
    }

    /// 解析单个会话文件
    static func parseSessionFile(_ file: URL) -> [ClaudeEvent] {
        var events: [ClaudeEvent] = []

        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return [] }

        for line in content.components(separatedBy: .newlines) {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }

            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let event = parseEvent(json: json) {
                        events.append(event)
                    }
                }
            }
        }

        return events
    }

    /// 解析单个事件
    private static func parseEvent(json: [String: Any]) -> ClaudeEvent? {
        guard let type = json["type"] as? String else { return nil }

        let timestamp = (json["timestamp"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()

        switch type {
        case "user":
            return parseUserEvent(json: json, timestamp: timestamp)
        case "assistant":
            return parseAssistantEvent(json: json, timestamp: timestamp)
        default:
            return nil
        }
    }

    private static func parseUserEvent(json: [String: Any], timestamp: Date) -> ClaudeEvent? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }

        var text = ""
        for item in content {
            if item["type"] as? String == "text", let t = item["text"] as? String {
                text += t
            }
        }

        return ClaudeEvent(
            type: .user,
            timestamp: timestamp,
            content: text,
            toolCalls: [],
            filesRead: [],
            filesWritten: [],
            filesEdited: []
        )
    }

    private static func parseAssistantEvent(json: [String: Any], timestamp: Date) -> ClaudeEvent? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }

        var text = ""
        var toolCalls: [ToolCall] = []
        var filesRead: [String] = []
        var filesWritten: [String] = []
        var filesEdited: [String] = []

        for item in content {
            let itemType = item["type"] as? String

            if itemType == "text", let t = item["text"] as? String {
                text += t
            }

            if itemType == "tool_use" {
                let toolName = item["name"] as? String ?? ""
                let input = item["input"] as? [String: Any] ?? [:]

                var summary = ""
                if let filePath = input["file_path"] as? String {
                    summary = filePath
                    if toolName == "Read" {
                        filesRead.append(filePath)
                    } else if toolName == "Write" {
                        filesWritten.append(filePath)
                    } else if toolName == "Edit" {
                        filesEdited.append(filePath)
                    }
                } else if let command = input["command"] as? String {
                    summary = command.prefix(100).description
                }

                toolCalls.append(ToolCall(
                    tool: toolName,
                    summary: summary,
                    timestamp: timestamp
                ))
            }
        }

        return ClaudeEvent(
            type: .assistant,
            timestamp: timestamp,
            content: text,
            toolCalls: toolCalls,
            filesRead: filesRead,
            filesWritten: filesWritten,
            filesEdited: filesEdited
        )
    }

    /// 提取会话摘要
    private static func extractSessionSummary(events: [ClaudeEvent], sessionId: String) -> ClaudeSession {
        let userEvents = events.filter { $0.type == .user }
        let assistantEvents = events.filter { $0.type == .assistant }

        // 合并所有文件操作
        var allFilesRead: Set<String> = []
        var allFilesWritten: Set<String> = []
        var allFilesEdited: Set<String> = []
        var allToolCalls: [ToolCall] = []

        for event in assistantEvents {
            allFilesRead.formUnion(event.filesRead)
            allFilesWritten.formUnion(event.filesWritten)
            allFilesEdited.formUnion(event.filesEdited)
            allToolCalls.append(contentsOf: event.toolCalls)
        }

        // 提取第一个用户消息作为标题
        let title = userEvents.first?.content.prefix(100).description ?? "会话"

        // 统计
        let stats = ClaudeSessionStats(
            userMessages: userEvents.count,
            assistantMessages: assistantEvents.count,
            toolCalls: allToolCalls.count,
            filesRead: allFilesRead.count,
            filesWritten: allFilesWritten.count,
            filesEdited: allFilesEdited.count
        )

        return ClaudeSession(
            id: sessionId,
            title: title,
            startedAt: events.first?.timestamp ?? Date(),
            lastActivity: events.last?.timestamp ?? Date(),
            stats: stats,
            filesRead: Array(allFilesRead).sorted(),
            filesWritten: Array(allFilesWritten).sorted(),
            filesEdited: Array(allFilesEdited).sorted(),
            toolCalls: allToolCalls
        )
    }

    /// 将 Claude 会话转换为生成记录
    static func toGenerationRecords(sessions: [ClaudeSession], projectPath: String) -> [GenerationRecord] {
        var records: [GenerationRecord] = []

        for session in sessions {
            // 为每个有文件写入/编辑的会话创建记录
            let generatedFiles = session.filesWritten + session.filesEdited

            if !generatedFiles.isEmpty {
                // 提取相对路径
                let relativePaths = generatedFiles.map { path -> String in
                    if path.hasPrefix(projectPath) {
                        return String(path.dropFirst(projectPath.count + 1))
                    }
                    return path
                }

                // 推断生成类型
                let kind = inferGenerationKind(files: relativePaths)

                let record = GenerationRecord(
                    id: "claude-\(session.id)",
                    timestamp: session.lastActivity,
                    kind: kind,
                    title: session.title,
                    description: "生成了 \(generatedFiles.count) 个文件",
                    sourcePrompt: nil,
                    generatedFiles: relativePaths,
                    status: .pending,
                    reviewNotes: nil,
                    reviewedAt: nil
                )
                records.append(record)
            }
        }

        return records.sorted { $0.timestamp > $1.timestamp }
    }

    /// 推断生成类型
    private static func inferGenerationKind(files: [String]) -> GenerationKind {
        var typeCounts: [GenerationKind: Int] = [:]

        for file in files {
            let ext = URL(fileURLWithPath: file).pathExtension.lowercased()
            let path = file.lowercased()

            // 前端页面
            if ["tsx", "jsx", "vue", "svelte"].contains(ext) {
                if path.contains("page") || path.contains("view") || path.contains("screen") {
                    typeCounts[.page, default: 0] += 1
                } else if path.contains("component") {
                    typeCounts[.component, default: 0] += 1
                } else {
                    typeCounts[.page, default: 0] += 1
                }
            }

            // API
            if ext == "py" && (path.contains("api") || path.contains("route") || path.contains("endpoint")) {
                typeCounts[.api, default: 0] += 1
            }
            if ["ts", "js"].contains(ext) && path.contains("api") {
                typeCounts[.api, default: 0] += 1
            }

            // 数据库
            if ext == "sql" || path.contains("migration") || path.contains("model") {
                typeCounts[.database, default: 0] += 1
            }

            // Swift
            if ext == "swift" {
                if path.contains("view") {
                    typeCounts[.page, default: 0] += 1
                } else if path.contains("model") || path.contains("entity") {
                    typeCounts[.database, default: 0] += 1
                }
            }
        }

        // 返回最多的类型
        return typeCounts.sorted { $0.value > $1.value }.first?.key ?? .component
    }
}

// MARK: - 数据模型

struct ClaudeSession: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startedAt: Date
    let lastActivity: Date
    let stats: ClaudeSessionStats
    let filesRead: [String]
    let filesWritten: [String]
    let filesEdited: [String]
    let toolCalls: [ToolCall]
}

struct ClaudeSessionStats: Codable, Hashable {
    let userMessages: Int
    let assistantMessages: Int
    let toolCalls: Int
    let filesRead: Int
    let filesWritten: Int
    let filesEdited: Int
}

struct ClaudeEvent: Codable, Hashable {
    let type: ClaudeEventType
    let timestamp: Date
    let content: String
    let toolCalls: [ToolCall]
    let filesRead: [String]
    let filesWritten: [String]
    let filesEdited: [String]
}

enum ClaudeEventType: String, Codable, Hashable {
    case user
    case assistant
}

struct ToolCall: Codable, Hashable {
    let tool: String
    let summary: String
    let timestamp: Date
}

// MARK: - Codex 日志解析

enum CodexSessionService {

    /// 从 Codex SQLite 数据库读取会话
    static func readSessions(for projectPath: String) -> [CodexSession] {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/logs_2.sqlite")

        guard FileManager.default.fileExists(atPath: dbPath.path) else { return [] }

        // SQLite 需要通过命令行工具读取
        // 这里返回空，实际使用时需要调用 sqlite3 命令
        return []
    }

    /// 使用 sqlite3 命令读取 Codex 日志
    static func readCodexLogs() -> [CodexSession] {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/logs_2.sqlite").path

        // 查询最近的会话
        let query = "SELECT id, timestamp, prompt, response FROM sessions ORDER BY timestamp DESC LIMIT 50;"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath, query]

        guard let output = try? process.runAndWaitForOutput() else { return [] }

        // 解析输出
        var sessions: [CodexSession] = []
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 4 {
                sessions.append(CodexSession(
                    id: parts[0],
                    timestamp: parts[1],
                    prompt: parts[2],
                    response: parts[3]
                ))
            }
        }

        return sessions
    }
}

struct CodexSession: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: String
    let prompt: String
    let response: String
}

// MARK: - Process 辅助扩展

extension Process {
    func runAndWaitForOutput() throws -> String {
        let pipe = Pipe()
        self.standardOutput = pipe
        try self.run()
        self.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}