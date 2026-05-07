import Foundation

enum ProjectScanner {
    static let trackedExtensions: Set<String> = ["ts", "tsx", "js", "jsx", "json", "css", "md", "py", "sql", "swift", "kt", "java", "go", "rs"]
    private static let ignoredDirectories: Set<String> = [
        "node_modules", ".git", "dist", "build", "out", ".next", ".nuxt",
        "coverage", ".cache", ".turbo", ".vibe-tracking", ".venv", "venv",
        "__pycache__", ".mypy_cache", ".tox", ".idea", ".vscode", "target",
        "DerivedData", ".build", "Pods", ".swiftpm", "Carthage", "Build"
    ]
    private static let ignoredFiles: Set<String> = [
        ".DS_Store", "Thumbs.db", ".env", ".env.local", ".env.production",
        "package-lock.json", "tsconfig.tsbuildinfo"
    ]
    private static let sharedComponentPatterns: Set<String> = [
        "Button", "Card", "Modal", "Input", "Select", "Form", "Table", "List",
        "Header", "Footer", "Sidebar", "Navbar", "Menu", "Dropdown", "Tooltip",
        "Dialog", "Alert", "Toast", "Badge", "Avatar", "Icon", "Loader", "Spinner",
        "Tabs", "Accordion", "Pagination", "Search", "Filter", "DatePicker",
        "Calendar", "Upload", "Chart", "Graph", "Map", "Editor", "Skeleton",
        "Empty", "Error", "Loading", "Progress", "Stepper", "Breadcrumb", "Tag",
        "Divider", "Container", "Layout", "Grid", "Stack", "Popover", "Drawer",
        "Switch", "Checkbox", "Radio", "Slider"
    ]
    private static let hookPatterns: [String] = [
        "useState", "useEffect", "useContext", "useReducer", "useCallback",
        "useMemo", "useRef", "useLayoutEffect", "useTransition", "useId",
        "useSelector", "useDispatch", "useNavigate", "useLocation", "useParams",
        "useSearchParams", "useQuery", "useMutation", "useForm", "useDebounce",
        "useLocalStorage", "useHover", "useFocus", "useMediaQuery", "useToggle"
    ]

    static func scan(root: URL, recentChanges: [FileChange], controlState: UserControlState) -> ActivityData {
        let recentCommits = GitService.recentCommits(in: root)
        let todayCommits = GitService.todayCommits(in: root)

        // 检测项目类型
        let projectType = detectProjectType(root: root)
        let appleProject = detectAppleProject(root: root)
        let genericProject = scanGenericProject(root: root)

        // 根据项目类型选择扫描策略
        let frontendScan: FrontendScanResult
        let backendApis: [BackendApi]
        let databaseTables: [DatabaseTable]

        if appleProject != nil {
            // Apple 项目：将 Swift Views 作为前端页面
            frontendScan = scanAppleFrontend(appleProject: appleProject!, root: root)
            backendApis = [] // Apple 项目通常没有传统后端 API
            databaseTables = scanAppleDataModels(appleProject: appleProject!, root: root)
        } else {
            // Web/其他项目：使用原有扫描逻辑
            frontendScan = scanFrontendFull(root: root)
            backendApis = scanBackendApis(root: root)
            databaseTables = scanDatabaseTables(root: root)
        }

        let aiLogic = detectAiLogicNames(root: root)
        let vibeHarness = HarnessService.status(root: root)
        let ruleChecks = HarnessService.ruleCheckReport(
            root: root,
            frontendPages: frontendScan.pages,
            recentChanges: recentChanges
        )
        let workflow = HarnessService.workflowReport(
            root: root,
            controlState: controlState,
            frontendPages: frontendScan.pages,
            recentChanges: recentChanges,
            ruleChecks: ruleChecks.checks
        )

        return ActivityData(
            recentCommits: recentCommits,
            todayCommits: todayCommits,
            todayStats: GitService.todayStats(in: root, commits: todayCommits),
            recentChanges: recentChanges,
            projectStructure: projectStructure(root: root),
            techStack: scanTechStack(root: root),
            frontendPages: frontendScan.pages,
            frontendScan: frontendScan,
            backendApis: backendApis,
            backendFlows: scanBackendFlows(root: root),
            databaseTables: databaseTables,
            aiLogs: scanAILogs(root: root),
            unitTests: scanUnitTests(root: root),
            codeStandards: scanCodeStandards(root: root),
            uiStandards: scanUIStandards(root: root),
            codeQuality: scanCodeQuality(root: root),
            controlState: controlState,
            vibeHarness: vibeHarness,
            vibeRuleChecks: ruleChecks,
            vibeWorkflow: workflow,
            vibeInventory: VibeProjectInventory(
                projectName: root.lastPathComponent,
                frontendPages: frontendScan.pages.map(formatFrontendPageTrackItem).sorted(),
                backendApis: detectFastApiRoutes(root: root),
                databaseTables: databaseTables.map(\.name).sorted(),
                aiLogic: aiLogic,
                appleProject: appleProject,
                genericProject: genericProject,
                projectType: projectType.displayName
            )
        )
    }

    /// Apple 项目前端扫描（将 SwiftUI Views 作为页面）
    static func scanAppleFrontend(appleProject: AppleProjectInfo, root: URL) -> FrontendScanResult {
        let pages = appleProject.views.map { view -> FrontendPage in
            FrontendPage(
                name: view.name,
                path: view.path,
                route: view.hasNavigation ? "/\(view.name.lowercased())" : "/",
                category: view.type == .swiftUI ? "SwiftUI" : "UIKit",
                description: view.description,
                tasks: [],
                componentCount: 1,
                modules: [],
                sharedComponents: [],
                localComponents: [],
                hooksUsed: [],
                fileSize: 0,
                lastModified: nil
            )
        }

        let categories = Dictionary(grouping: pages, by: \.category)
            .map { NamedCount(name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        return FrontendScanResult(
            pages: pages,
            sharedComponents: [],
            categories: categories,
            totalComponents: pages.count,
            totalHooks: 0
        )
    }

    /// Apple 项目数据模型扫描（将 Swift Models 作为数据库表）
    static func scanAppleDataModels(appleProject: AppleProjectInfo, root: URL) -> [DatabaseTable] {
        return appleProject.models.map { model -> DatabaseTable in
            let columns = model.properties.map { prop ->
                TableColumn in
                TableColumn(
                    name: prop.name,
                    type: prop.type,
                    nullable: !prop.type.contains("?"),
                    primaryKey: prop.name.lowercased() == "id",
                    default: nil
                )
            }
            return DatabaseTable(
                name: model.name,
                columns: columns,
                relations: []
            )
        }
    }

    static func collectFiles(
        root: URL,
        extensions: Set<String>,
        pathHints: [String] = [],
        maxDepth: Int = 8,
        limit: Int = 2_000
    ) -> [URL] {
        var output: [URL] = []

        func walk(_ url: URL, depth: Int) {
            guard output.count < limit, depth <= maxDepth else { return }
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for entry in entries.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }) {
                guard output.count < limit else { return }
                let name = entry.lastPathComponent
                if ignoredFiles.contains(name) { continue }
                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDirectory {
                    if ignoredDirectories.contains(name) { continue }
                    walk(entry, depth: depth + 1)
                } else {
                    let ext = entry.pathExtension.lowercased()
                    guard extensions.contains(ext) else { continue }
                    if !pathHints.isEmpty {
                        let relative = entry.relativePath(from: root).lowercased()
                        guard pathHints.contains(where: { relative.contains($0.lowercased()) }) else { continue }
                    }
                    output.append(entry)
                }
            }
        }

        walk(root, depth: 0)
        return output
    }

    static func projectStructure(root: URL, maxDepth: Int = 3) -> [TreeNode] {
        func walk(_ url: URL, depth: Int) -> [TreeNode] {
            guard depth <= maxDepth else { return [] }
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            return entries
                .filter { !ignoredFiles.contains($0.lastPathComponent) }
                .sorted { lhs, rhs in
                    let lhsDir = ((try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
                    let rhsDir = ((try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
                    if lhsDir != rhsDir { return lhsDir && !rhsDir }
                    return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
                }
                .compactMap { entry in
                    let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDirectory && ignoredDirectories.contains(entry.lastPathComponent) { return nil }
                    return TreeNode(
                        name: entry.lastPathComponent,
                        path: entry.path,
                        type: isDirectory ? .folder : .file,
                        children: isDirectory ? walk(entry, depth: depth + 1) : [],
                        depth: depth
                    )
                }
        }

        return walk(root, depth: 0)
    }

    static func scanFrontendFull(root: URL) -> FrontendScanResult {
        let frontendDirs = detectFrontendDirs(root: root)
        var pages: [FrontendPage] = []
        var seen = Set<String>()
        var componentUsage: [String: (path: String, pages: Set<String>)] = [:]

        for dir in frontendDirs {
            let files = collectFiles(root: dir, extensions: ["tsx", "jsx", "vue"], maxDepth: 8, limit: 1_500)
            for file in files where isPageFile(file.lastPathComponent) {
                let page = analyzePageFile(file: file, workspaceRoot: root)
                guard !seen.contains(page.path) else { continue }
                seen.insert(page.path)
                pages.append(page)

                let pageLabel = page.route.isEmpty ? page.name : page.route
                for component in page.sharedComponents + page.localComponents {
                    var bucket = componentUsage[component] ?? (path: page.path, pages: [])
                    bucket.pages.insert(pageLabel)
                    componentUsage[component] = bucket
                }
            }
        }

        let shared = componentUsage
            .filter { $0.value.pages.count > 1 || sharedComponentPatterns.contains($0.key) }
            .map { SharedComponent(name: $0.key, path: $0.value.path, usageCount: $0.value.pages.count, usedInPages: Array($0.value.pages).sorted()) }
            .sorted { $0.usageCount > $1.usageCount }

        let categoryCounts = Dictionary(grouping: pages, by: \.category)
            .map { NamedCount(name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        return FrontendScanResult(
            pages: pages.sorted { $0.path < $1.path },
            sharedComponents: shared,
            categories: categoryCounts,
            totalComponents: pages.reduce(0) { $0 + $1.componentCount },
            totalHooks: pages.reduce(0) { $0 + $1.hooksUsed.count }
        )
    }

    static func scanBackendApis(root: URL) -> [BackendApi] {
        let files = collectFiles(root: root, extensions: ["py"], pathHints: ["backend/app/api", "api", "server", "src"], maxDepth: 9, limit: 1_200)
        var apis: [BackendApi] = []

        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                guard let match = line.firstMatch(#"@(app|router)\.(get|post|put|delete|patch|options|head)\(\s*["']([^"']+)["']"#, options: [.caseInsensitive]),
                      match.count >= 4,
                      let method = HttpMethod(rawValue: match[2].uppercased())
                else { continue }

                let functionName = extractFunctionName(lines: lines, startIndex: index) ?? "Unnamed API"
                let endpoint = match[3]
                apis.append(BackendApi(
                    name: functionName,
                    path: file.relativePath(from: root),
                    method: method,
                    endpoint: endpoint,
                    description: extractApiDescription(lines: lines, startIndex: index),
                    category: file.deletingLastPathComponent().lastPathComponent,
                    completed: !line.contains("TODO") && !line.contains("FIXME"),
                    responseFields: max(2, min(12, functionName.count % 10 + 2))
                ))
            }
        }

        return apis.sorted { $0.id < $1.id }
    }

    static func scanBackendFlows(root: URL) -> [BackendFlow] {
        let services = root.child("backend/app/services")
        guard FileManager.default.fileExistsAndIsDirectory(at: services) else { return [] }
        let files = collectFiles(root: services, extensions: ["py"], maxDepth: 2, limit: 300)

        return files
            .filter { !$0.lastPathComponent.hasPrefix("__") }
            .map { file in
                let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                let functionNames = content.allMatches(#"(?:def|async\s+def)\s+([A-Za-z_][A-Za-z0-9_]*)"#)
                    .compactMap { $0.count > 1 ? $0[1] : nil }
                    .filter { !$0.hasPrefix("_") }
                    .uniqued()
                let steps = functionNames.map { name in
                    FlowStep(
                        name: name.readableTitle(),
                        completed: !content.contains("TODO") && !content.contains("pass"),
                        details: "函数 \(name)"
                    )
                }
                let completed = steps.filter(\.completed).count
                return BackendFlow(
                    name: file.deletingPathExtension().lastPathComponent.readableTitle(),
                    description: extractDescription(content),
                    steps: steps,
                    completedPercent: steps.isEmpty ? 100 : Int((Double(completed) / Double(steps.count)) * 100)
                )
            }
            .sorted { $0.name < $1.name }
    }

    static func scanDatabaseTables(root: URL) -> [DatabaseTable] {
        var tables: [String: DatabaseTable] = [:]

        func upsert(_ table: DatabaseTable) {
            var existing = tables[table.name] ?? DatabaseTable(name: table.name, columns: [], relations: [])
            for column in table.columns where !existing.columns.contains(where: { $0.name == column.name }) {
                existing.columns.append(column)
            }
            for relation in table.relations where !existing.relations.contains(relation) {
                existing.relations.append(relation)
            }
            tables[table.name] = existing
        }

        // SQL 文件：移除路径限制，扫描所有 SQL 文件
        let sqlFiles = collectFiles(root: root, extensions: ["sql"], maxDepth: 10, limit: 800)
        for file in sqlFiles {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            parseSQLTables(content).forEach(upsert)
        }

        // Python 文件：移除路径限制，扫描所有 Python 文件
        let pythonFiles = collectFiles(root: root, extensions: ["py"], maxDepth: 10, limit: 2_000)
        for file in pythonFiles {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            parsePythonTables(content).forEach(upsert)
        }

        // 从 .vibe/track.md 补充已有表定义
        let trackURL = root.child(".vibe/track.md")
        if let trackContent = try? String(contentsOf: trackURL, encoding: .utf8) {
            let trackedTables = parseTrackDatabaseTables(trackContent)
            trackedTables.forEach(upsert)
        }

        return tables.values
            .filter { !$0.columns.isEmpty || !$0.relations.isEmpty }
            .sorted { $0.name < $1.name }
    }

    static func detectFastApiRoutes(root: URL) -> [String] {
        scanBackendApis(root: root).map { "\($0.method.rawValue) \($0.endpoint)" }.uniqued().sorted()
    }

    static func detectDatabaseTableNames(root: URL) -> [String] {
        scanDatabaseTables(root: root).map(\.name).sorted()
    }

    static func detectAiLogicNames(root: URL) -> [String] {
        let roots = ["ai", "agents", "chains", "prompts"]
            .map { root.child($0) }
            .filter { FileManager.default.fileExistsAndIsDirectory(at: $0) }
        guard !roots.isEmpty else { return [] }

        var names = Set<String>()
        for aiRoot in roots {
            let files = collectFiles(root: aiRoot, extensions: ["py", "ts", "tsx", "js", "md"], maxDepth: 6, limit: 700)
            for file in files {
                let base = file.deletingPathExtension().lastPathComponent
                if base.count > 1 && !base.hasPrefix("__") {
                    names.insert(base.readableTitle())
                }
                if let content = try? String(contentsOf: file, encoding: .utf8) {
                    for match in content.allMatches(#"(?:def|function|const|class)\s+([A-Za-z_][A-Za-z0-9_]*(?:Agent|Chain|Prompt|Tool|Workflow|Graph)[A-Za-z0-9_]*)"#) {
                        if match.count > 1 { names.insert(match[1].readableTitle()) }
                    }
                }
            }
        }

        return Array(names).sorted()
    }

    static func scanAILogs(root: URL) -> [AILog] {
        let markers: [(String, String)] = [
            (#"ai[_-]?path"#, "AI Pipeline"),
            (#"langgraph"#, "LangGraph"),
            (#"openai|minimax|claude|anthropic"#, "LLM Integration"),
            (#"tavily|serper"#, "Search API"),
            (#"chunk|embedding|vector"#, "Vector Search")
        ]
        let files = collectFiles(root: root, extensions: trackedExtensions, pathHints: ["ai", "backend/app/api", "frontend/src/modules", "agents", "chains"], maxDepth: 8, limit: 1_000)
        return files.compactMap { file in
            let name = file.lastPathComponent
            guard let marker = markers.first(where: { name.containsRegex($0.0, options: [.caseInsensitive]) }) else { return nil }
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
            return AILog(
                timestamp: attrs?[.modificationDate] as? Date ?? Date(),
                action: marker.1,
                details: "\(attrs?[.size] as? Int ?? 0) bytes - \(file.relativePath(from: root))"
            )
        }
        .sorted { $0.timestamp > $1.timestamp }
        .prefix(50)
        .map { $0 }
    }

    static func scanTechStack(root: URL) -> [TechStack] {
        var stacks: [TechStack] = []
        if let packageURL = ["frontend/package.json", "package.json", "webview/package.json", "web/package.json"]
            .map({ root.child($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }),
           let package = readJSONDictionary(packageURL) {
            let deps = ((package["dependencies"] as? [String: Any]) ?? [:]).merging((package["devDependencies"] as? [String: Any]) ?? [:]) { first, _ in first }
            let names: [(String, String, String?)] = [
                ("react", "React", deps["react"] as? String),
                ("vue", "Vue", deps["vue"] as? String),
                ("@angular/core", "Angular", deps["@angular/core"] as? String),
                ("svelte", "Svelte", deps["svelte"] as? String),
                ("vite", "Vite", deps["vite"] as? String),
                ("webpack", "Webpack", deps["webpack"] as? String),
                ("next", "Next.js", deps["next"] as? String),
                ("nuxt", "Nuxt.js", deps["nuxt"] as? String),
                ("typescript", "TypeScript", deps["typescript"] as? String),
                ("tailwindcss", "TailwindCSS", deps["tailwindcss"] as? String),
                ("react-router", "React Router", (deps["react-router-dom"] as? String) ?? (deps["react-router"] as? String)),
                ("zustand", "Zustand", deps["zustand"] as? String),
                ("redux", "Redux", (deps["redux"] as? String) ?? (deps["@reduxjs/toolkit"] as? String)),
                ("lucide-react", "Lucide Icons", deps["lucide-react"] as? String),
                ("vitest", "Vitest", deps["vitest"] as? String),
                ("jest", "Jest", deps["jest"] as? String),
                ("axios", "Axios", deps["axios"] as? String),
                ("@tanstack/react-query", "React Query", deps["@tanstack/react-query"] as? String)
            ]
            let frontendItems = names.compactMap { key, name, version -> TechStackItem? in
                deps[key] == nil && version == nil ? nil : TechStackItem(name: name, version: version, description: nil)
            }
            if !frontendItems.isEmpty {
                stacks.append(TechStack(category: "Frontend", items: frontendItems))
            }
        }

        if let reqURL = ["backend/requirements.txt", "requirements.txt", "api/requirements.txt"]
            .map({ root.child($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            let lines = ((try? String(contentsOf: reqURL, encoding: .utf8)) ?? "")
                .components(separatedBy: .newlines)
                .compactMap { $0.nonEmpty }
                .filter { !$0.hasPrefix("#") }
            let backendItems = lines.prefix(20).map { line -> TechStackItem in
                let parts = line.components(separatedBy: CharacterSet(charactersIn: "=<>"))
                return TechStackItem(name: parts.first?.trimmingCharacters(in: .whitespaces) ?? line, version: parts.dropFirst().first?.trimmingCharacters(in: .whitespaces), description: backendDependencyCategory(line.lowercased()))
            }
            if !backendItems.isEmpty { stacks.append(TechStack(category: "Backend", items: backendItems)) }
        }

        let aiReq = ["ai_path/requirements.txt", "ai/requirements.txt", "ml/requirements.txt"]
            .map { root.child($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        if let aiReq {
            let items = ((try? String(contentsOf: aiReq, encoding: .utf8)) ?? "")
                .components(separatedBy: .newlines)
                .compactMap { $0.nonEmpty }
                .filter { !$0.hasPrefix("#") }
                .prefix(15)
                .map { TechStackItem(name: $0.components(separatedBy: CharacterSet(charactersIn: "=<>")).first ?? $0, version: nil, description: nil) }
            if !items.isEmpty { stacks.append(TechStack(category: "AI / ML", items: Array(items))) }
        }

        var database: [TechStackItem] = []
        if FileManager.default.fileExists(atPath: root.child("supabase").path) || FileManager.default.fileExists(atPath: root.child("backend/alembic").path) {
            database.append(TechStackItem(name: "PostgreSQL", version: nil, description: "Primary database"))
        }
        if FileManager.default.fileExists(atPath: root.child("supabase").path) {
            database.append(TechStackItem(name: "Supabase", version: nil, description: "Backend-as-a-Service"))
        }
        if FileManager.default.fileExists(atPath: root.child("backend/alembic").path) {
            database.append(TechStackItem(name: "Alembic", version: nil, description: "Database migrations"))
        }
        if FileManager.default.fileExists(atPath: root.child("prisma").path) {
            database.append(TechStackItem(name: "Prisma", version: nil, description: "ORM & migrations"))
        }
        if FileManager.default.fileExists(atPath: root.child("db.sqlite3").path) || FileManager.default.fileExists(atPath: root.child("database.sqlite").path) {
            database.append(TechStackItem(name: "SQLite", version: nil, description: "Embedded database"))
        }
        if !database.isEmpty { stacks.append(TechStack(category: "Database", items: database)) }

        // Apple/Swift 项目检测
        var appleStack: [TechStackItem] = []
        let packageSwift = root.child("Package.swift")
        if FileManager.default.fileExists(atPath: packageSwift.path) {
            appleStack.append(TechStackItem(name: "Swift Package Manager", version: nil, description: "Dependency management"))
        }
        if FileManager.default.fileExists(atPath: root.child("Podfile").path) {
            appleStack.append(TechStackItem(name: "CocoaPods", version: nil, description: "Dependency management"))
        }
        if FileManager.default.fileExists(atPath: root.child("Cartfile").path) {
            appleStack.append(TechStackItem(name: "Carthage", version: nil, description: "Dependency management"))
        }
        if (try? FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasSuffix(".xcodeproj") }) == true {
            appleStack.append(TechStackItem(name: "Xcode Project", version: nil, description: "IDE & Build System"))
        }

        // 检测 Swift 文件判断 Swift 版本
        let swiftFiles = collectFiles(root: root, extensions: ["swift"], maxDepth: 3, limit: 10)
        if !swiftFiles.isEmpty {
            appleStack.insert(TechStackItem(name: "Swift", version: nil, description: "Programming Language"), at: 0)
        }

        // 检测 SwiftUI/UIKit
        if let firstSwift = swiftFiles.first, let content = try? String(contentsOf: firstSwift, encoding: .utf8) {
            if content.contains("SwiftUI") {
                appleStack.append(TechStackItem(name: "SwiftUI", version: nil, description: "UI Framework"))
            }
            if content.contains("UIKit") {
                appleStack.append(TechStackItem(name: "UIKit", version: nil, description: "UI Framework"))
            }
            if content.contains("AppKit") {
                appleStack.append(TechStackItem(name: "AppKit", version: nil, description: "macOS UI Framework"))
            }
            if content.contains("Combine") {
                appleStack.append(TechStackItem(name: "Combine", version: nil, description: "Reactive Framework"))
            }
            if content.contains("CoreData") || content.contains("@Entity") {
                appleStack.append(TechStackItem(name: "Core Data", version: nil, description: "Persistence"))
            }
        }

        if !appleStack.isEmpty { stacks.append(TechStack(category: "Apple", items: appleStack)) }

        var infra: [TechStackItem] = []
        if FileManager.default.fileExists(atPath: root.child("Dockerfile").path) || FileManager.default.fileExists(atPath: root.child("docker-compose.yml").path) {
            infra.append(TechStackItem(name: "Docker", version: nil, description: "Containerization"))
        }
        if FileManager.default.fileExists(atPath: root.child(".github/workflows").path) {
            infra.append(TechStackItem(name: "GitHub Actions", version: nil, description: "CI/CD"))
        }
        if FileManager.default.fileExists(atPath: root.child(".git").path) {
            infra.append(TechStackItem(name: "Git", version: nil, description: "Version control"))
        }
        if !infra.isEmpty { stacks.append(TechStack(category: "Infrastructure", items: infra)) }

        return stacks
    }

    static func scanUnitTests(root: URL) -> UnitTestSummary {
        let files = collectFiles(root: root, extensions: ["ts", "tsx", "js", "jsx", "py", "go", "java", "swift"], maxDepth: 9, limit: 1_500)
            .filter { file in
                let lower = file.lastPathComponent.lowercased()
                return lower.contains(".test.") || lower.contains(".spec.") || lower.hasPrefix("test_") || lower.hasSuffix("_test.go") || lower.hasSuffix("tests.swift") || lower.contains("tests")
            }
        let testFiles = files.map { file -> UnitTestFile in
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let framework = inferTestFramework(file: file, content: content)
            let testCount = content.allMatches(#"\b(it|test|describe|def\s+test_|func\s+Test|XCTest)\b"#).count
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
            return UnitTestFile(name: file.lastPathComponent, path: file.relativePath(from: root), framework: framework, testCount: testCount, lastModified: attrs?[.modificationDate] as? Date)
        }
        return UnitTestSummary(
            files: testFiles.sorted { $0.path < $1.path },
            frameworks: Array(Set(testFiles.map(\.framework))).sorted(),
            totalTests: testFiles.reduce(0) { $0 + $1.testCount },
            hasCoverage: FileManager.default.fileExists(atPath: root.child("coverage").path) || FileManager.default.fileExists(atPath: root.child(".coverage").path)
        )
    }

    static func scanCodeStandards(root: URL) -> CodeStandards {
        let configs: [(String, String, String)] = [
            (".eslintrc", "ESLint", "eslint"),
            (".eslintrc.json", "ESLint", "eslint"),
            ("eslint.config.js", "ESLint", "eslint"),
            (".prettierrc", "Prettier", "prettier"),
            ("pyproject.toml", "Ruff/Black", "ruff"),
            ("ruff.toml", "Ruff", "ruff"),
            (".golangci.yml", "golangci-lint", "golangci"),
            ("clippy.toml", "Clippy", "clippy")
        ]
        let found = configs.compactMap { relative, name, type -> LinterConfig? in
            let url = root.child(relative)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return LinterConfig(name: name, path: relative, type: type, rules: [])
        }
        let package = readJSONDictionary(root.child("tsconfig.json"))
        let compiler = package?["compilerOptions"] as? [String: Any]
        let strict = compiler?["strict"] as? Bool ?? false
        return CodeStandards(
            linters: found.filter { $0.type != "prettier" },
            formatters: found.filter { $0.type == "prettier" || $0.name.contains("Black") },
            hasStrictMode: strict,
            typeSafetyConfigPath: package == nil ? nil : "tsconfig.json",
            isConfigured: !found.isEmpty || strict
        )
    }

    static func scanUIStandards(root: URL) -> UIStandards {
        let package = readJSONDictionary(root.child("package.json")) ?? readJSONDictionary(root.child("frontend/package.json")) ?? [:]
        let deps = ((package["dependencies"] as? [String: Any]) ?? [:]).merging((package["devDependencies"] as? [String: Any]) ?? [:]) { first, _ in first }
        let cssFramework: String
        if deps["tailwindcss"] != nil || FileManager.default.fileExists(atPath: root.child("tailwind.config.js").path) {
            cssFramework = "tailwind"
        } else if deps["styled-components"] != nil {
            cssFramework = "styled-components"
        } else {
            cssFramework = "none"
        }

        let componentLibs = ["antd", "@mui/material", "@chakra-ui/react", "lucide-react"]
            .filter { deps[$0] != nil }
        let cssFiles = collectFiles(root: root, extensions: ["css"], pathHints: ["src", "frontend", "webview"], maxDepth: 7, limit: 100)
        let tokens = cssFiles.flatMap { file -> [UIToken] in
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            return content.allMatches(#"--([A-Za-z0-9_-]+)\s*:\s*([^;]+);"#).prefix(30).map { match in
                let name = match.count > 1 ? match[1] : "token"
                let value = match.count > 2 ? match[2].trimmingCharacters(in: .whitespaces) : ""
                let type = value.contains("#") || value.contains("rgb") ? "color" : value.contains("px") || value.contains("rem") ? "spacing" : "other"
                return UIToken(name: name, value: value, type: type)
            }
        }

        return UIStandards(cssFramework: cssFramework, configPath: cssFramework == "tailwind" ? "tailwind.config.js" : nil, tokens: tokens, componentLibs: componentLibs, isConfigured: cssFramework != "none" || !tokens.isEmpty || !componentLibs.isEmpty)
    }

    static func scanCodeQuality(root: URL) -> CodeQualityReport {
        let files = collectFiles(root: root, extensions: ["ts", "tsx", "js", "jsx", "py"], maxDepth: 8, limit: 900)
        var checks: [CodeQualityCheck] = []
        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                let relative = file.relativePath(from: root)
                if line.contains("TODO") || line.contains("FIXME") {
                    checks.append(CodeQualityCheck(category: "comments", file: relative, line: index + 1, severity: line.contains("FIXME") ? .warning : .info, message: "存在 TODO/FIXME 标记", suggestion: "把临时标记转成明确任务或收尾实现"))
                }
                if line.contains("eval(") {
                    checks.append(CodeQualityCheck(category: "security", file: relative, line: index + 1, severity: .error, message: "检测到 eval 调用", suggestion: "避免动态执行不可信代码"))
                }
                if line.contains("console.log") || line.contains("print(") {
                    checks.append(CodeQualityCheck(category: "comments", file: relative, line: index + 1, severity: .info, message: "可能遗留调试输出", suggestion: "发布前确认是否需要结构化日志"))
                }
                if line.contains("except:") || line.contains("catch {}") {
                    checks.append(CodeQualityCheck(category: "error", file: relative, line: index + 1, severity: .warning, message: "发现过宽的错误吞掉逻辑", suggestion: "至少记录错误并说明恢复策略"))
                }
            }
        }

        let categoryCounts = Dictionary(grouping: checks, by: \.category).map { NamedCount(name: $0.key, count: $0.value.count) }
        let severityCounts = Dictionary(grouping: checks, by: { $0.severity.rawValue }).map { NamedCount(name: $0.key, count: $0.value.count) }
        let penalty = checks.reduce(0) { sum, check in
            sum + (check.severity == .error ? 12 : check.severity == .warning ? 5 : 1)
        }
        let summary = CodeQualitySummary(total: checks.count, byCategory: categoryCounts.sorted { $0.count > $1.count }, bySeverity: severityCounts.sorted { $0.count > $1.count }, score: max(0, 100 - penalty))
        return CodeQualityReport(checks: Array(checks.prefix(120)), summary: summary)
    }
}

extension ProjectScanner {
    static func detectFrontendDirs(root: URL) -> [URL] {
        let patterns = ["frontend/src", "web/src", "src", "app", "pages", "views", "client/src", "webapp/src", "ui/src", "webview/src", "frontend/src/modules"]
        var dirs: [URL] = []
        for pattern in patterns {
            let url = root.child(pattern)
            if FileManager.default.fileExistsAndIsDirectory(at: url), hasFrameworkFiles(url) {
                dirs.append(url)
            }
        }
        return dirs.uniqued()
    }

    static func hasFrameworkFiles(_ dir: URL, depth: Int = 0) -> Bool {
        guard depth < 6,
              let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return false }
        for entry in entries {
            if ["tsx", "jsx", "vue"].contains(entry.pathExtension.lowercased()) { return true }
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory && !ignoredDirectories.contains(entry.lastPathComponent) && hasFrameworkFiles(entry, depth: depth + 1) {
                return true
            }
        }
        return false
    }

    static func isPageFile(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        if ["page.tsx", "page.jsx", "index.tsx", "index.jsx", "main.tsx", "main.jsx", "page.vue", "index.vue"].contains(lower) {
            return true
        }
        if lower.contains(".test.") || lower.contains(".spec.") || lower.contains(".stories.") || lower.contains(".d.") {
            return false
        }
        return lower.hasSuffix(".tsx") || lower.hasSuffix(".jsx") || lower.hasSuffix(".vue")
    }

    static func analyzePageFile(file: URL, workspaceRoot: URL) -> FrontendPage {
        let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        let modules = extractModules(content)
        let localComponents = extractLocalComponents(content)
        let sharedComponents = extractSharedComponents(content: content, modules: modules)
        let hooks = hookPatterns.filter { content.contains($0) }
        let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
        return FrontendPage(
            name: extractPageName(file),
            path: file.relativePath(from: workspaceRoot),
            route: extractRoute(file: file, workspaceRoot: workspaceRoot, content: content),
            category: detectCategory(file: file, workspaceRoot: workspaceRoot),
            description: extractDescription(content),
            tasks: extractTasks(content),
            componentCount: (localComponents + sharedComponents).uniqued().count,
            modules: modules,
            sharedComponents: sharedComponents,
            localComponents: localComponents,
            hooksUsed: hooks,
            fileSize: attrs?[.size] as? Int ?? 0,
            lastModified: attrs?[.modificationDate] as? Date
        )
    }

    static func extractPageName(_ file: URL) -> String {
        let base = file.deletingPathExtension().lastPathComponent
        if ["index", "page", "main"].contains(base.lowercased()) {
            return file.deletingLastPathComponent().lastPathComponent.readableTitle()
        }
        return base.readableTitle()
    }

    static func extractRoute(file: URL, workspaceRoot: URL, content: String) -> String {
        if let match = content.firstMatch(#"(?:route|path)\s*[=:]\s*["'`]([^"'`]+)["'`]"#), match.count > 1 {
            return match[1]
        }
        let parts = file.relativePath(from: workspaceRoot)
            .split(separator: "/")
            .map(String.init)
        let markers = ["pages", "views", "routes", "app", "src"]
        guard let markerIndex = parts.firstIndex(where: { markers.contains($0.lowercased()) }) else { return "/" }
        let routeParts = parts.dropFirst(markerIndex + 1).map { part -> String in
            let noExt = URL(fileURLWithPath: part).deletingPathExtension().lastPathComponent
            return ["index", "page", "main"].contains(noExt.lowercased()) ? "" : noExt.lowercased()
        }
        let route = "/" + routeParts.filter { !$0.isEmpty }.joined(separator: "/")
        return route == "/" ? "/" : route.replacingOccurrences(of: "//", with: "/")
    }

    static func detectCategory(file: URL, workspaceRoot: URL) -> String {
        let categoryMap: [String: String] = [
            "home": "首页", "dashboard": "仪表盘", "user": "用户", "users": "用户",
            "auth": "认证", "login": "登录", "admin": "管理", "settings": "设置",
            "profile": "个人中心", "ai": "AI", "learning": "学习", "course": "课程",
            "resource": "资源", "project": "项目", "projects": "项目"
        ]
        let parts = file.relativePath(from: workspaceRoot).split(separator: "/").map { String($0).lowercased() }
        for part in parts {
            if let category = categoryMap[part] { return category }
        }
        return file.deletingLastPathComponent().lastPathComponent.readableTitle()
    }

    static func extractModules(_ content: String) -> [ImportedModule] {
        let importMatches = content.allMatches(#"import\s+(?:[^"']+?\s+from\s+)?["']([^"']+)["']"#) + content.allMatches(#"require\(["']([^"']+)["']\)"#)
        return importMatches.compactMap { match in
            guard match.count > 1 else { return nil }
            let modulePath = match[1]
            let type: ImportedModuleType = modulePath.hasPrefix(".") ? .relative : modulePath.hasPrefix("@/") ? .local : .npm
            return ImportedModule(
                name: modulePath.split(separator: "/").last.map(String.init) ?? modulePath,
                path: modulePath,
                type: type,
                isComponent: modulePath.contains("component") || modulePath.split(separator: "/").last?.first?.isUppercase == true
            )
        }
    }

    static func extractLocalComponents(_ content: String) -> [String] {
        let functionComponents = content.allMatches(#"(?:function|const)\s+([A-Z][A-Za-z0-9_]*)"#).compactMap { $0.count > 1 ? $0[1] : nil }
        let jsxComponents = content.allMatches(#"<([A-Z][A-Za-z0-9_.]*)\b"#).compactMap { $0.count > 1 ? $0[1].components(separatedBy: ".").first : nil }
        return (functionComponents + jsxComponents).compactMap { $0 }.uniqued().sorted()
    }

    static func extractSharedComponents(content: String, modules: [ImportedModule]) -> [String] {
        var names = Set<String>()
        for module in modules where module.isComponent {
            names.insert(module.name.replacingOccurrences(of: ".tsx", with: "").replacingOccurrences(of: ".jsx", with: ""))
        }
        for pattern in sharedComponentPatterns where content.contains("<\(pattern)") || content.contains("\(pattern)(") {
            names.insert(pattern)
        }
        return Array(names).sorted()
    }

    static func extractTasks(_ content: String) -> [TodoTask] {
        content.allMatches(#"(?i)((?:TODO|FIXME|HACK):\s*)([^\n]+)"#).enumerated().map { index, match in
            let marker = match.count > 1 ? match[1].uppercased() : "TODO"
            let title = match.count > 2 ? match[2].trimmingCharacters(in: .whitespaces) : "待处理任务"
            return TodoTask(id: "task-\(index)", title: title, completed: false, priority: marker.contains("FIXME") ? .high : .medium)
        }
    }

    static func extractDescription(_ content: String) -> String {
        if let match = content.firstMatch(#"(?:description|DESCRIPTION):\s*["']([^"']+)["']"#), match.count > 1 {
            return match[1]
        }
        if let match = content.firstMatch(#"/\*\*\s*\n\s*\*\s*([^\n*]+)"#), match.count > 1 {
            return match[1].trimmingCharacters(in: .whitespaces)
        }
        return "No description"
    }

    static func extractFunctionName(lines: [String], startIndex: Int) -> String? {
        for line in lines[startIndex..<min(startIndex + 10, lines.count)] {
            if let match = line.firstMatch(#"^\s*(?:async\s+)?def\s+([A-Za-z_][A-Za-z0-9_]*)"#), match.count > 1 {
                return match[1]
            }
        }
        return nil
    }

    static func extractApiDescription(lines: [String], startIndex: Int) -> String {
        for line in lines[startIndex..<min(startIndex + 8, lines.count)] {
            if let match = line.firstMatch(#"(?:"{3}|'{3})\s*([^"']+)"#), match.count > 1 {
                return match[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "No description"
    }

    static func parseSQLTables(_ content: String) -> [DatabaseTable] {
        // 移除 SQL 注释便于解析
        let normalized = content
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
            .joined(separator: " ")
        
        // 匹配 CREATE TABLE，支持多行
        return normalized.allMatches(#"(?is)create\s+(?:temp\s+)?table\s+(?:if\s+not\s+exists\s+)?(?:\w+\.)?[`\"']?([A-Za-z0-9_]+)[`\"']?\s*\(([^)]+(?:\([^)]*\)[^)]*)*(?:\([^)]*\)[^)]*)*\)"#).compactMap { match in
            guard match.count > 2 else { return nil }
            let tableName = match[1].normalizedEntity()
            let body = match[2]
            let columns = extractSQLColumns(body)
            let relations = body.allMatches(#"foreign\s+key\s*\(([^)]+)\)\s+references\s+([A-Za-z0-9_]+)\s*\(([^)]+)\)"#, options: [.caseInsensitive]).compactMap { rel -> TableRelation? in
                guard rel.count > 3 else { return nil }
                return TableRelation(fromColumn: rel[1].trimmingCharacters(in: .whitespaces), toTable: rel[2], toColumn: rel[3].trimmingCharacters(in: .whitespaces), type: "one-to-many")
            }
            return DatabaseTable(name: tableName, columns: columns, relations: relations)
        }
    }
    
    private static func extractSQLColumns(_ body: String) -> [TableColumn] {
        var columns: [TableColumn] = []
        let lines = body.components(separatedBy: ",")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            guard !lower.hasPrefix("primary") && !lower.hasPrefix("foreign") && !lower.hasPrefix("constraint") && !lower.hasPrefix("unique") && !lower.hasPrefix("check") else { continue }
            
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 2 else { continue }
            
            let name = parts[0].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "`", with: "").replacingOccurrences(of: "'", with: "")
            let typeAndConstraints = parts.dropFirst().joined(separator: " ")
            let type = typeAndConstraints.split(separator: " ").first.map(String.init) ?? "unknown"
            let nullable = !typeAndConstraints.lowercased().contains("not null")
            let isPrimaryKey = typeAndConstraints.lowercased().contains("primary key")
            
            columns.append(TableColumn(name: name, type: type, nullable: nullable, primaryKey: isPrimaryKey, default: nil))
        }
        return columns
    }

    static func parsePythonTables(_ content: String) -> [DatabaseTable] {
        var tables: [String: DatabaseTable] = [:]
        
        // 方式 1: 从 SQLAlchemy/SQLModel 类提取
        extractPythonORMTables(content).forEach { table in
            if tables[table.name] == nil {
                tables[table.name] = table
            } else {
                var existing = tables[table.name]!
                for col in table.columns where !existing.columns.contains(where: { $0.name == col.name }) {
                    existing.columns.append(col)
                }
                tables[table.name] = existing
            }
        }
        
        // 方式 2: 从 Alembic migration 提取
        for match in content.allMatches(#"op\.create_table\(\s*[\"']([A-Za-z0-9_]+)[\"'](.*?)\)"#, options: [.dotMatchesLineSeparators]) where match.count > 2 {
            let tableName = match[1].lowercased()
            let columns = match[2].allMatches(#"sa\.Column\(\s*[\"']([^\"']+)[\"']\s*,\s*sa\.([A-Za-z0-9_]+)"#).compactMap { col -> TableColumn? in
                guard col.count > 2 else { return nil }
                return TableColumn(name: col[1], type: col[2], nullable: !match[2].contains("nullable=False"), primaryKey: match[2].contains("primary_key=True"), default: nil)
            }
            if !columns.isEmpty {
                tables[tableName] = DatabaseTable(name: tableName, columns: columns, relations: [])
            }
        }
        
        return Array(tables.values)
    }
    
    private static func extractPythonORMTables(_ content: String) -> [DatabaseTable] {
        var tables: [DatabaseTable] = []
        
        // 匹配类定义
        let classPattern = #"class\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*(?:Base|SQLModel|DeclarativeBase|db\.Model)[^)]*)\)\s*:([^c]*?)(?=\nclass\s+|\Z)"#
        for match in content.allMatches(classPattern, options: [.dotMatchesLineSeparators]) where match.count > 3 {
            let className = match[1]
            let classBody = match[3]
            
            // 查找 __tablename__
            var tableName: String?
            if let tableMatch = classBody.firstMatch(#"__tablename__\s*=\s*[\"']([A-Za-z0-9_]+)[\"']"#), tableMatch.count > 1 {
                tableName = tableMatch[1].lowercased()
            } else {
                tableName = toTableName(className)
            }
            
            let columns = extractPythonColumns(classBody)
            if !columns.isEmpty {
                tables.append(DatabaseTable(name: tableName ?? className.lowercased(), columns: columns, relations: []))
            }
        }
        
        return tables
    }
    
    private static func extractPythonColumns(_ classBody: String) -> [TableColumn] {
        var columns: [TableColumn] = []
        
        // SQLAlchemy: Column('name', String, ...)
        for match in classBody.allMatches(#"Column\s*\(\s*[\"']([^\"']+)[\"']\s*,\s*([A-Za-z0-9_.]+)"#) where match.count > 2 {
            let name = match[1]
            let type = match[2]
            let nullable = !classBody.contains("nullable=False")
            columns.append(TableColumn(name: name, type: type, nullable: nullable, primaryKey: false, default: nil))
        }
        
        return columns
    }

    static func toTableName(_ className: String) -> String {
        let withUnderscores = className.replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1_$2", options: .regularExpression)
        return withUnderscores.lowercased()
            .replacingOccurrences(of: "_model$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "_table$", with: "", options: .regularExpression)
    }
    
    private static func parseTrackDatabaseTables(_ content: String) -> [DatabaseTable] {
        // 从 .vibe/track.md 的 Database 部分提取已登记表
        guard let dbSection = content.firstMatch(#"(?s)##\s+Database\s*\n(.*?)(?=\n##|\Z)"#), dbSection.count > 1 else { return [] }
        
        let items = dbSection[1]
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("-") else { return nil }
                let item = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                return item.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.hasPrefix("暂未识别") && !$0.hasPrefix("...") }
        
        return items.map { DatabaseTable(name: $0, columns: [], relations: []) }
    }

    static func readJSONDictionary(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    static func backendDependencyCategory(_ package: String) -> String? {
        let categories: [(String, [String])] = [
            ("Web Framework", ["fastapi", "flask", "django", "express", "nestjs"]),
            ("ORM/Database", ["sqlalchemy", "sqlmodel", "prisma", "typeorm"]),
            ("Database Driver", ["psycopg", "mysql", "mongodb", "redis", "sqlite", "pg"]),
            ("Auth", ["jose", "passlib", "bcrypt", "jwt", "authlib"]),
            ("AI/ML", ["langchain", "langgraph", "openai", "anthropic", "transformers", "torch"])
        ]
        return categories.first { _, libs in libs.contains { package.contains($0) } }?.0
    }

    static func inferTestFramework(file: URL, content: String) -> String {
        let lower = file.lastPathComponent.lowercased()
        if lower.hasSuffix(".swift") { return "XCTest" }
        if lower.hasSuffix(".py") { return "pytest" }
        if lower.hasSuffix("_test.go") { return "go" }
        if content.contains("vitest") { return "vitest" }
        if content.contains("jest") { return "jest" }
        if content.contains("mocha") { return "mocha" }
        if lower.hasSuffix(".java") { return "junit" }
        return "unknown"
    }

    static func formatFrontendPageTrackItem(_ page: FrontendPage) -> String {
        let route = page.route != "/" && !page.route.isEmpty ? page.route : page.path
        return "\(route) - \(page.name)"
    }
}

// MARK: - iOS/macOS Project Scanning

extension ProjectScanner {

    /// 检测是否为 Apple 平台项目 (iOS/macOS/watchOS/tvOS)
    static func detectAppleProject(root: URL) -> AppleProjectInfo? {
        // 检查 Xcode 项目文件
        let xcodeProj = root.appendingPathComponent("\(root.lastPathComponent).xcodeproj")
        let xcworkspace = root.appendingPathComponent("\(root.lastPathComponent).xcworkspace")
        let packageSwift = root.appendingPathComponent("Package.swift")

        let hasXcodeProj = FileManager.default.fileExists(atPath: xcodeProj.path)
        let hasWorkspace = FileManager.default.fileExists(atPath: xcworkspace.path)
        let hasPackageSwift = FileManager.default.fileExists(atPath: packageSwift.path)

        guard hasXcodeProj || hasWorkspace || hasPackageSwift else { return nil }

        // 检测平台
        var platforms: [String] = []
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: root.path) {
            for item in contents {
                if item.hasSuffix(".xcodeproj") || item.hasSuffix(".xcworkspace") {
                    // 存在 Xcode 项目文件
                    break
                }
            }
        }

        // 扫描源文件目录
        var sourceDirs = ["Sources", "Source", "src", "App", "iOS", "macOS", "Shared"]
            .map { root.appendingPathComponent($0) }
            .filter { FileManager.default.fileExistsAndIsDirectory(at: $0) }

        if sourceDirs.isEmpty && hasPackageSwift {
            // SPM 项目，Sources 目录可能在根目录
            if FileManager.default.fileExistsAndIsDirectory(at: root.appendingPathComponent("Sources")) {
                sourceDirs.append(root.appendingPathComponent("Sources"))
            }
        }

        // 扫描 Swift 文件
        var swiftFiles: [URL] = []
        for dir in sourceDirs {
            swiftFiles += collectFiles(root: dir, extensions: ["swift"], maxDepth: 8, limit: 500)
        }

        // 如果没有找到源文件目录，扫描整个项目
        if swiftFiles.isEmpty {
            swiftFiles = collectFiles(root: root, extensions: ["swift"], maxDepth: 8, limit: 500)
        }

        // 分析 Swift 视图/屏幕
        let views = scanSwiftViews(files: swiftFiles, root: root)

        // 分析 Swift 数据模型
        let models = scanSwiftModels(files: swiftFiles, root: root)

        // 分析 Swift 服务/API
        let services = scanSwiftServices(files: swiftFiles, root: root)

        // 检测平台
        let content = swiftFiles.compactMap { try? String(contentsOf: $0) }.joined(separator: "\n")
        if content.contains("UIKit") || content.contains("UIViewController") {
            platforms.append("iOS")
        }
        if content.contains("AppKit") || content.contains("NSView") {
            platforms.append("macOS")
        }
        if content.contains("SwiftUI") {
            if platforms.isEmpty {
                platforms.append("Multi-platform")
            }
        }
        if platforms.isEmpty {
            platforms.append("Swift")
        }

        return AppleProjectInfo(
            name: root.lastPathComponent,
            platforms: platforms,
            hasXcodeProj: hasXcodeProj,
            hasWorkspace: hasWorkspace,
            hasPackageSwift: hasPackageSwift,
            swiftFiles: swiftFiles.count,
            views: views,
            models: models,
            services: services
        )
    }

    /// 扫描 Swift 视图 (SwiftUI Views 或 UIKit ViewControllers)
    static func scanSwiftViews(files: [URL], root: URL) -> [SwiftView] {
        var views: [SwiftView] = []

        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let relativePath = file.relativePath(from: root)

            // SwiftUI View
            let swiftUIViewPattern = #"struct\s+([A-Z][A-Za-z0-9_]*)\s*:\s*View"#
            for match in content.allMatches(swiftUIViewPattern) where match.count > 1 {
                let viewName = match[1]
                let isPreview = content.contains("#Preview") || content.contains("PreviewProvider")
                let hasNavigation = content.contains("NavigationStack") || content.contains("NavigationView")

                views.append(SwiftView(
                    name: viewName,
                    path: relativePath,
                    type: .swiftUI,
                    isPreview: isPreview,
                    hasNavigation: hasNavigation,
                    description: extractSwiftDescription(content: content, structName: viewName)
                ))
            }

            // UIKit ViewController
            let viewControllerPattern = #"class\s+([A-Z][A-Za-z0-9_]*)\s*(?::\s*UIViewController|,\s*UIViewController)"#
            for match in content.allMatches(viewControllerPattern) where match.count > 1 {
                let viewName = match[1]
                views.append(SwiftView(
                    name: viewName,
                    path: relativePath,
                    type: .uikit,
                    isPreview: false,
                    hasNavigation: content.contains("UINavigationController"),
                    description: extractSwiftDescription(content: content, structName: viewName)
                ))
            }
        }

        return views.sorted { $0.name < $1.name }
    }

    /// 扫描 Swift 数据模型
    static func scanSwiftModels(files: [URL], root: URL) -> [SwiftModel] {
        var models: [SwiftModel] = []

        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let relativePath = file.relativePath(from: root)

            // Codable models
            let modelPattern = #"struct\s+([A-Z][A-Za-z0-9_]*)\s*(?::\s*(?:Codable|Identifiable|ObservableObject|Hashable))"#
            for match in content.allMatches(modelPattern) where match.count > 1 {
                let modelName = match[1]
                let properties = extractSwiftProperties(content: content, structName: modelName)

                models.append(SwiftModel(
                    name: modelName,
                    path: relativePath,
                    properties: properties,
                    isObservable: content.contains("ObservableObject")
                ))
            }

            // Core Data entities (simplified)
            let entityPattern = #"@Entity\s+class\s+([A-Z][A-Za-z0-9_]*)"#
            for match in content.allMatches(entityPattern) where match.count > 1 {
                let modelName = match[1]
                models.append(SwiftModel(
                    name: modelName,
                    path: relativePath,
                    properties: extractSwiftProperties(content: content, structName: modelName),
                    isObservable: false
                ))
            }
        }

        return models.sorted { $0.name < $1.name }
    }

    /// 扫描 Swift 服务/API 调用
    static func scanSwiftServices(files: [URL], root: URL) -> [SwiftService] {
        var services: [SwiftService] = []

        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let relativePath = file.relativePath(from: root)

            // URLSession API calls
            if content.contains("URLSession") || content.contains("URLSession.shared") {
                let apiEndpoints = extractAPIEndpoints(content: content)
                services.append(SwiftService(
                    name: file.deletingPathExtension().lastPathComponent,
                    path: relativePath,
                    type: .network,
                    endpoints: apiEndpoints
                ))
            }

            // Combine publishers
            if content.contains("PassthroughSubject") || content.contains("CurrentValueSubject") {
                services.append(SwiftService(
                    name: file.deletingPathExtension().lastPathComponent,
                    path: relativePath,
                    type: .combine,
                    endpoints: []
                ))
            }

            // Async/Await services
            if content.contains("async") && content.contains("await") {
                services.append(SwiftService(
                    name: file.deletingPathExtension().lastPathComponent,
                    path: relativePath,
                    type: .asyncAwait,
                    endpoints: []
                ))
            }
        }

        return services.sorted { $0.name < $1.name }
    }

    private static func extractSwiftDescription(content: String, structName: String) -> String {
        // 提取文档注释
        let pattern = #"///\s*([^\n]+)"#
        let matches = content.allMatches(pattern)
        if let firstMatch = matches.first, firstMatch.count > 1 {
            return firstMatch[1].trimmingCharacters(in: .whitespaces)
        }
        return "No description"
    }

    private static func extractSwiftProperties(content: String, structName: String) -> [SwiftProperty] {
        var properties: [SwiftProperty] = []

        // 简单提取属性
        let propertyPattern = #"let\s+([a-z][A-Za-z0-9_]*)\s*:\s*([A-Za-z0-9_<>?\[\]]+)"#
        for match in content.allMatches(propertyPattern) where match.count > 2 {
            properties.append(SwiftProperty(
                name: match[1],
                type: match[2]
            ))
        }

        let varPattern = #"var\s+([a-z][A-Za-z0-9_]*)\s*:\s*([A-Za-z0-9_<>?\[\]]+)"#
        for match in content.allMatches(varPattern) where match.count > 2 {
            if !properties.contains(where: { $0.name == match[1] }) {
                properties.append(SwiftProperty(
                    name: match[1],
                    type: match[2]
                ))
            }
        }

        return properties
    }

    private static func extractAPIEndpoints(content: String) -> [String] {
        var endpoints: [String] = []

        let urlPattern = #"["']https?://[^"']+["']"#
        for match in content.allMatches(urlPattern) {
            let url = match[0].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
            endpoints.append(url)
        }

        return endpoints.uniqued()
    }
}

// MARK: - Generic Project Scanning

extension ProjectScanner {

    /// 检测通用项目类型
    static func detectProjectType(root: URL) -> ProjectType {
        // 检查各种项目标记文件
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            return .swiftPackage
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("Cargo.toml").path) {
            return .rust
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("go.mod").path) {
            return .go
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("pom.xml").path) ||
           FileManager.default.fileExists(atPath: root.appendingPathComponent("build.gradle").path) {
            return .java
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("package.json").path) {
            // 进一步检测前端框架
            if let package = readJSONDictionary(root.appendingPathComponent("package.json")) {
                let deps = (package["dependencies"] as? [String: Any]) ?? [:]
                if deps["next"] != nil { return .nextjs }
                if deps["nuxt"] != nil { return .nuxt }
                if deps["react"] != nil { return .react }
                if deps["vue"] != nil { return .vue }
                if deps["@angular/core"] != nil { return .angular }
                if deps["svelte"] != nil { return .svelte }
            }
            return .nodejs
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("requirements.txt").path) ||
           FileManager.default.fileExists(atPath: root.appendingPathComponent("pyproject.toml").path) {
            return .python
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("Gemfile").path) {
            return .ruby
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("composer.json").path) {
            return .php
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent(".xcodeproj").path) ||
           FileManager.default.fileExists(atPath: root.child(root.lastPathComponent + ".xcodeproj").path) {
            return .apple
        }

        // 检查文件扩展名分布
        let allFiles = collectFiles(root: root, extensions: trackedExtensions, maxDepth: 4, limit: 200)
        let extCounts = Dictionary(grouping: allFiles, by: { $0.pathExtension.lowercased() })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }

        if let top = extCounts.first {
            switch top.0 {
            case "swift": return .swiftPackage
            case "rs": return .rust
            case "go": return .go
            case "kt", "java": return .java
            case "py": return .python
            case "ts", "tsx", "js", "jsx": return .nodejs
            default: break
            }
        }

        return .generic
    }

    /// 扫描通用项目结构
    static func scanGenericProject(root: URL) -> GenericProjectInfo {
        let projectType = detectProjectType(root: root)

        // 收集所有源文件
        let sourceFiles = collectFiles(root: root, extensions: trackedExtensions, maxDepth: 10, limit: 2000)

        // 分析目录结构
        var directories: [String] = []
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                if let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                    let relative = url.relativePath(from: root)
                    if !relative.contains("/.") && !ignoredDirectories.contains(url.lastPathComponent) {
                        directories.append(relative)
                    }
                }
                if directories.count > 100 { break }
            }
        }

        // 按扩展名分组统计
        let fileTypes = Dictionary(grouping: sourceFiles, by: { $0.pathExtension.lowercased() })
            .map { FileTypeStats(extension: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // 提取主要入口文件
        let entryPoints = detectEntryPoints(files: sourceFiles, root: root)

        // 提取配置文件
        let configFiles = detectConfigFiles(root: root)

        return GenericProjectInfo(
            type: projectType,
            totalFiles: sourceFiles.count,
            directories: directories.prefix(50).map { $0 },
            fileTypes: fileTypes.prefix(15).map { $0 },
            entryPoints: entryPoints,
            configFiles: configFiles
        )
    }

    private static func detectEntryPoints(files: [URL], root: URL) -> [String] {
        let entryFileNames = ["main", "index", "app", "server", "run", "start"]
        var entries: [String] = []

        for file in files {
            let name = file.deletingPathExtension().lastPathComponent.lowercased()
            if entryFileNames.contains(name) {
                entries.append(file.relativePath(from: root))
            }
        }

        return entries.sorted()
    }

    private static func detectConfigFiles(root: URL) -> [String] {
        let configPatterns = [
            "package.json", "Cargo.toml", "go.mod", "pom.xml", "build.gradle",
            "requirements.txt", "pyproject.toml", "Gemfile", "composer.json",
            "tsconfig.json", ".eslintrc", ".prettierrc", "tailwind.config",
            "vite.config", "webpack.config", "rollup.config",
            "docker-compose.yml", "Dockerfile", ".github/workflows",
            "Makefile", "CMakeLists.txt", "Package.swift"
        ]

        return configPatterns.filter { pattern in
            FileManager.default.fileExists(atPath: root.appendingPathComponent(pattern).path)
        }
    }
}

// MARK: - Supporting Types

struct AppleProjectInfo: Codable, Hashable {
    let name: String
    let platforms: [String]
    let hasXcodeProj: Bool
    let hasWorkspace: Bool
    let hasPackageSwift: Bool
    let swiftFiles: Int
    let views: [SwiftView]
    let models: [SwiftModel]
    let services: [SwiftService]
}

struct SwiftView: Identifiable, Codable, Hashable {
    var id: String { "\(path)-\(name)" }
    let name: String
    let path: String
    let type: SwiftViewType
    let isPreview: Bool
    let hasNavigation: Bool
    let description: String
}

enum SwiftViewType: String, Codable, Hashable {
    case swiftUI
    case uikit
    case storyboard
}

struct SwiftModel: Identifiable, Codable, Hashable {
    var id: String { "\(path)-\(name)" }
    let name: String
    let path: String
    let properties: [SwiftProperty]
    let isObservable: Bool
}

struct SwiftProperty: Codable, Hashable {
    let name: String
    let type: String
}

struct SwiftService: Identifiable, Codable, Hashable {
    var id: String { "\(path)-\(name)" }
    let name: String
    let path: String
    let type: SwiftServiceType
    let endpoints: [String]
}

enum SwiftServiceType: String, Codable, Hashable {
    case network
    case combine
    case asyncAwait
    case coreData
}

enum ProjectType: String, Codable, Hashable {
    case swiftPackage = "Swift Package"
    case apple = "Apple (iOS/macOS)"
    case rust = "Rust"
    case go = "Go"
    case java = "Java/Kotlin"
    case python = "Python"
    case nodejs = "Node.js"
    case nextjs = "Next.js"
    case nuxt = "Nuxt.js"
    case react = "React"
    case vue = "Vue"
    case angular = "Angular"
    case svelte = "Svelte"
    case ruby = "Ruby"
    case php = "PHP"
    case generic = "Generic"

    var displayName: String { rawValue }
}

struct GenericProjectInfo: Codable, Hashable {
    let type: ProjectType
    let totalFiles: Int
    let directories: [String]
    let fileTypes: [FileTypeStats]
    let entryPoints: [String]
    let configFiles: [String]
}

struct FileTypeStats: Codable, Hashable {
    let `extension`: String
    let count: Int
}
