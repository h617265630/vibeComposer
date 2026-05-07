import Foundation

struct FileSignature: Equatable {
    let modifiedAt: Date
    let size: Int
}

final class FileSnapshotTracker {
    private var snapshot: [String: FileSignature] = [:]

    func detectChanges(root: URL) -> [FileChange] {
        let files = ProjectScanner.collectFiles(
            root: root,
            extensions: ProjectScanner.trackedExtensions,
            maxDepth: 10,
            limit: 4_000
        )

        var next: [String: FileSignature] = [:]
        let manager = FileManager.default

        for file in files {
            guard let attributes = try? manager.attributesOfItem(atPath: file.path) else { continue }
            let modifiedAt = attributes[.modificationDate] as? Date ?? Date()
            let size = attributes[.size] as? Int ?? 0
            next[file.relativePath(from: root)] = FileSignature(modifiedAt: modifiedAt, size: size)
        }

        if snapshot.isEmpty {
            snapshot = next
            return seedRecentChanges(root: root, snapshot: next)
        }

        var changes: [FileChange] = []
        for (relativePath, signature) in next {
            if let previous = snapshot[relativePath] {
                if previous != signature {
                    changes.append(makeChange(root: root, relativePath: relativePath, type: .modified, timestamp: signature.modifiedAt))
                }
            } else {
                changes.append(makeChange(root: root, relativePath: relativePath, type: .created, timestamp: signature.modifiedAt))
            }
        }

        for (relativePath, signature) in snapshot where next[relativePath] == nil {
            changes.append(makeChange(root: root, relativePath: relativePath, type: .deleted, timestamp: signature.modifiedAt))
        }

        snapshot = next
        return changes.sorted { $0.timestamp > $1.timestamp }
    }

    func reset() {
        snapshot = [:]
    }

    private func seedRecentChanges(root: URL, snapshot: [String: FileSignature]) -> [FileChange] {
        snapshot
            .sorted { $0.value.modifiedAt > $1.value.modifiedAt }
            .prefix(16)
            .map { relativePath, signature in
                makeChange(root: root, relativePath: relativePath, type: .modified, timestamp: signature.modifiedAt)
            }
    }

    private func makeChange(root: URL, relativePath: String, type: FileChangeType, timestamp: Date) -> FileChange {
        let url = root.child(relativePath)
        return FileChange(
            type: type,
            path: url.path,
            relativePath: relativePath,
            timestamp: timestamp,
            fileExtension: url.pathExtension.lowercased()
        )
    }
}
