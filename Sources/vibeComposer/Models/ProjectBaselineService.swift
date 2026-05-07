import Foundation

enum ProjectBaselineService {
    static func capture(from data: ActivityData, createdAt: Date = Date()) -> ProjectBaseline {
        ProjectBaseline(createdAt: createdAt, itemFingerprints: fingerprints(from: data))
    }

    static func fingerprints(from data: ActivityData) -> [String: String] {
        var values: [String: String] = [:]

        for page in data.frontendPages {
            values["page:\(page.path)"] = pageFingerprint(for: page)
        }

        for (name, group) in Dictionary(grouping: data.backendApis, by: apiGroupName) {
            values["feature:api:\(name)"] = apiGroupFingerprint(for: group)
        }

        if !data.databaseTables.isEmpty {
            values["feature:database"] = databaseFingerprint(for: data.databaseTables)
        }

        if !data.aiLogs.isEmpty || !data.vibeInventory.aiLogic.isEmpty {
            values["feature:ai"] = aiFingerprint(logs: data.aiLogs, inventory: data.vibeInventory.aiLogic)
        }

        return values
    }

    static func fingerprint(for id: String, in data: ActivityData) -> String? {
        fingerprints(from: data)[id]
    }

    static func isNewOrChanged(id: String, fingerprint: String, baseline: ProjectBaseline?) -> Bool {
        guard let baseline else { return false }
        return baseline.itemFingerprints[id] != fingerprint
    }

    static func isBaselineTracked(id: String, baseline: ProjectBaseline?) -> Bool {
        baseline?.itemFingerprints[id] != nil
    }

    static func apiGroupName(_ api: BackendApi) -> String {
        api.category.isEmpty ? api.endpoint.split(separator: "/").first.map(String.init) ?? "接口能力" : api.category
    }

    static func pageFingerprint(for page: FrontendPage) -> String {
        [
            page.path,
            page.route,
            "\(page.componentCount)",
            page.hooksUsed.sorted().joined(separator: ","),
            page.localComponents.sorted().joined(separator: ","),
            page.sharedComponents.sorted().joined(separator: ","),
            "\(page.fileSize)"
        ].joined(separator: "|")
    }

    static func apiGroupFingerprint(for group: [BackendApi]) -> String {
        group
            .map { api in
                [
                    api.method.rawValue,
                    api.endpoint,
                    api.path,
                    api.completed ? "done" : "todo",
                    "\(api.responseFields)"
                ].joined(separator: "|")
            }
            .sorted()
            .joined(separator: "\n")
    }

    static func databaseFingerprint(for tables: [DatabaseTable]) -> String {
        tables
            .map { table in
                let columns = table.columns
                    .map { "\($0.name):\($0.type):\($0.nullable):\($0.primaryKey):\($0.default ?? "")" }
                    .sorted()
                    .joined(separator: ",")
                let relations = table.relations
                    .map { "\($0.fromColumn):\($0.toTable):\($0.toColumn):\($0.type)" }
                    .sorted()
                    .joined(separator: ",")
                return "\(table.name)|\(columns)|\(relations)"
            }
            .sorted()
            .joined(separator: "\n")
    }

    static func aiFingerprint(logs: [AILog], inventory: [String]) -> String {
        let inventoryPart = inventory.sorted().joined(separator: ",")
        let logPart = logs
            .map { "\($0.action)|\($0.details)" }
            .sorted()
            .joined(separator: "\n")
        return "\(inventoryPart)\n\(logPart)"
    }
}
