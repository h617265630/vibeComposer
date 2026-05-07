import XCTest
@testable import vibeComposer

final class ScannerTests: XCTestCase {
    func testSQLTableParserReadsCreateTableColumns() {
        let sql = """
        create table users (
          id uuid primary key,
          email text not null,
          created_at timestamp
        );
        """

        let tables = ProjectScanner.parseSQLTables(sql)

        XCTAssertEqual(tables.first?.name, "users")
        XCTAssertEqual(tables.first?.columns.map(\.name), ["id", "email", "created_at"])
        XCTAssertEqual(tables.first?.columns.first?.primaryKey, true)
    }

    func testWorkflowChecklistParserKeepsCheckboxState() {
        let markdown = """
        # Harness Workflow
        - [x] 描述功能目标
        - [ ] 更新 track.md
        """

        let report = HarnessService.workflowReport(
            root: URL(fileURLWithPath: NSTemporaryDirectory()),
            controlState: .empty,
            frontendPages: [],
            recentChanges: [],
            ruleChecks: []
        )

        XCTAssertFalse(report.isConfigured)
        XCTAssertEqual(ProjectScanner.formatFrontendPageTrackItem(FrontendPage(name: "Home", path: "src/Home.tsx", route: "/", category: "首页", description: "", tasks: [], componentCount: 0, modules: [], sharedComponents: [], localComponents: [], hooksUsed: [], fileSize: 0, lastModified: nil)), "src/Home.tsx - Home")
        XCTAssertTrue(markdown.contains("更新 track.md"))
    }

    func testTrackRegistrationRepairAddsApiToBackendSection() {
        let content = """
        # Project Track

        ## Frontend Pages
        - 暂未识别到前端页面

        ## Backend API
        - 暂未识别到 FastAPI 路由

        ## Database
        - 暂未识别到数据库表
        """
        let check = VibeRuleCheck(
            id: "api",
            severity: .warning,
            title: "新 API 未登记到 track.md",
            message: "发现 GET /users",
            rule: "新 API 必须登记到 Backend API。",
            target: "GET /users"
        )

        let repaired = HarnessService.repairedTrackContent(content, for: check)

        XCTAssertTrue(repaired?.contains("## Backend API\n- GET /users") == true)
        XCTAssertFalse(repaired?.contains("暂未识别到 FastAPI 路由") == true)
    }

    func testTrackRegistrationRepairReturnsNilForUnsafeIssue() {
        let check = VibeRuleCheck(
            id: "deleted",
            severity: .error,
            title: "已有 API 被删除",
            message: "API deleted",
            rule: "不允许删除已有 API。",
            target: "GET /users"
        )

        XCTAssertNil(HarnessService.repairedTrackContent("# Project Track", for: check))
    }

    func testManualDecisionMarksSystemItemDone() {
        var data = ActivityData.empty
        data.databaseTables = [
            DatabaseTable(name: "users", columns: [], relations: [])
        ]
        data.controlState.decisions["feature:database"] = UserControlDecision(decision: .confirmed, updatedAt: Date())

        let progress = ProgressDeriver.derive(from: data)

        XCTAssertEqual(progress.features.first(where: { $0.id == "feature:database" })?.status, .done)
        XCTAssertFalse(progress.controls.contains(where: { $0.target == "feature:database" }))
    }
}
