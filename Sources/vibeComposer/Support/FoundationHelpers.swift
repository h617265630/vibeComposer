import Foundation

enum VibeDateFormatter {
    static var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static var gitDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }

    static var display: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    static func timeAgo(from date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "刚刚" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小时前" }
        let days = hours / 24
        if days < 7 { return "\(days) 天前" }
        return "\(days / 7) 周前"
    }
}

extension URL {
    func child(_ relativePath: String) -> URL {
        relativePath.split(separator: "/").reduce(self) { partial, segment in
            partial.appendingPathComponent(String(segment))
        }
    }

    func relativePath(from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let fullPath = standardizedFileURL.path
        guard fullPath.hasPrefix(rootPath) else { return fullPath }
        let dropped = fullPath.dropFirst(rootPath.count)
        return dropped.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func firstMatch(_ pattern: String, options: NSRegularExpression.Options = []) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range) else { return nil }
        return (0..<match.numberOfRanges).compactMap { index in
            let nsRange = match.range(at: index)
            guard let range = Range(nsRange, in: self) else { return nil }
            return String(self[range])
        }
    }

    func allMatches(_ pattern: String, options: NSRegularExpression.Options = []) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: range).map { match in
            (0..<match.numberOfRanges).compactMap { index in
                let nsRange = match.range(at: index)
                guard let range = Range(nsRange, in: self) else { return nil }
                return String(self[range])
            }
        }
    }

    func containsRegex(_ pattern: String, options: NSRegularExpression.Options = []) -> Bool {
        firstMatch(pattern, options: options) != nil
    }

    func normalizedEntity() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func readableTitle() -> String {
        split { char in
            char == "-" || char == "_" || char == "/" || char == "."
        }
        .filter { !$0.isEmpty }
        .map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }
        .joined(separator: " ")
    }

    func removingPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension FileManager {
    func fileExistsAndIsDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
