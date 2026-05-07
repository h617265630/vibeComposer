import Foundation

enum GitService {
    static func recentCommits(in root: URL, limit: Int = 15) -> [GitCommit] {
        let format = "%H%x1f%an%x1f%ad%x1f%s"
        let result = Shell.run([
            "/usr/bin/git",
            "log",
            "--max-count=\(limit)",
            "--date=iso",
            "--pretty=format:\(format)"
        ], currentDirectory: root)

        guard result.succeeded else { return [] }
        return result.output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseCommitLine(String($0)) }
    }

    static func todayCommits(in root: URL) -> [GitCommit] {
        let start = Calendar.current.startOfDay(for: Date())
        let since = VibeDateFormatter.iso8601.string(from: start)
        let format = "%H%x1f%an%x1f%ad%x1f%s"
        let result = Shell.run([
            "/usr/bin/git",
            "log",
            "--max-count=50",
            "--since=\(since)",
            "--date=iso",
            "--pretty=format:\(format)"
        ], currentDirectory: root)

        guard result.succeeded else { return [] }
        return result.output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseCommitLine(String($0)) }
    }

    static func todayStats(in root: URL, commits: [GitCommit]) -> TodayStats {
        var files = 0
        var insertions = 0
        var deletions = 0

        for commit in commits {
            let result = Shell.run([
                "/usr/bin/git",
                "show",
                "--shortstat",
                "--format=",
                commit.hash
            ], currentDirectory: root)

            guard result.succeeded else { continue }
            let text = result.output.replacingOccurrences(of: "\n", with: " ")
            if let fileValue = text.firstMatch(#"(\d+)\s+files?\s+changed"#)?[1], let value = Int(fileValue) {
                files += value
            }
            if let insertionValue = text.firstMatch(#"(\d+)\s+insertions?\(\+\)"#)?[1], let value = Int(insertionValue) {
                insertions += value
            }
            if let deletionValue = text.firstMatch(#"(\d+)\s+deletions?\(-\)"#)?[1], let value = Int(deletionValue) {
                deletions += value
            }
        }

        return TodayStats(commits: commits.count, filesChanged: files, insertions: insertions, deletions: deletions)
    }

    private static func parseCommitLine(_ line: String) -> GitCommit? {
        let parts = line.components(separatedBy: "\u{1f}")
        guard parts.count >= 4 else { return nil }
        let rawDate = parts[2].trimmingCharacters(in: .whitespaces)
        let date = VibeDateFormatter.gitDate.date(from: rawDate) ?? Date()
        let hash = parts[0]

        return GitCommit(
            hash: hash,
            shortHash: String(hash.prefix(7)),
            message: parts.dropFirst(3).joined(separator: " "),
            author: parts[1],
            date: date,
            timeAgo: VibeDateFormatter.timeAgo(from: date)
        )
    }
}
