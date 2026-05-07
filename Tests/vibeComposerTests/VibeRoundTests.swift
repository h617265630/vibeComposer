import XCTest
@testable import vibeComposer

final class VibeRoundTests: XCTestCase {
    func testStartRoundCapturesGoalRequirementsAndInitialGenerationCount() {
        var data = sampleData()
        data.controlState.goal = "完成订单管理 MVP"
        data.controlState.requirements = [
            ProjectRequirement(
                id: "orders",
                title: "用户可以管理订单",
                userValue: "运营人员能查看订单列表和状态",
                acceptanceCriteria: ["能打开订单页面", "能读取订单 API"],
                priority: .medium,
                status: .planned,
                updatedAt: Date()
            )
        ]
        data.controlState.generations = [
            GenerationRecord.create(kind: .page, title: "OrdersPage", description: "路由: /orders", files: ["src/pages/OrdersPage.tsx"])
        ]
        var state = data.controlState

        let round = VibeRoundService.startRound(in: &state, data: data, title: "订单管理")

        XCTAssertEqual(round.title, "订单管理")
        XCTAssertEqual(round.goal, "完成订单管理 MVP")
        XCTAssertEqual(round.requirementIDs, ["orders"])
        XCTAssertEqual(round.startGenerationCount, 1)
        XCTAssertNotNil(state.currentRound)
        XCTAssertEqual(state.timeline.first?.kind, .roundStart)
    }

    func testPromptCaptureStoresPromptAndReplySummaryInCurrentRound() {
        let data = sampleData()
        var state = data.controlState
        _ = VibeRoundService.startRound(in: &state, data: data, title: "订单管理")

        let prompt = VibeRoundService.addPrompt(
            to: &state,
            prompt: "请生成订单列表页面和订单 API",
            responseSummary: "生成了页面和 GET /orders",
            model: "Claude",
            source: "Cursor"
        )

        XCTAssertEqual(prompt.prompt, "请生成订单列表页面和订单 API")
        XCTAssertEqual(prompt.responseSummary, "生成了页面和 GET /orders")
        XCTAssertEqual(state.currentRound?.prompts.count, 1)
        XCTAssertEqual(state.timeline.first?.kind, .prompt)
    }

    func testInspectionTargetsIncludePreviewUrlsApiCommandsAndDatabaseTables() {
        let data = sampleData()
        let targets = VibeRoundService.inspectionTargets(for: data, previewBaseURL: "http://localhost:3000")

        XCTAssertTrue(targets.contains { $0.kind == .page && $0.title == "OrdersPage" && $0.openURL == "http://localhost:3000/orders" })
        XCTAssertTrue(targets.contains { $0.kind == .api && $0.command?.contains("GET http://localhost:3000/orders") == true })
        XCTAssertTrue(targets.contains { $0.kind == .database && $0.title == "orders" })
    }

    func testAlignmentPromptSummarizesRequirementEvidenceAndRisk() {
        var data = sampleData()
        data.controlState.requirements = [
            ProjectRequirement(
                id: "orders",
                title: "用户可以管理订单",
                userValue: "运营人员能查看订单列表和状态",
                acceptanceCriteria: ["能打开订单页面", "能读取订单 API"],
                priority: .medium,
                status: .planned,
                updatedAt: Date()
            )
        ]
        let item = ProgressDeriver.derive(from: data).features.first { $0.id == "requirement:orders" }!
        let report = ReviewService.alignmentReport(for: item, in: data)

        let prompt = VibeRoundService.alignmentPrompt(for: item, report: report)

        XCTAssertTrue(prompt.contains("用户可以管理订单"))
        XCTAssertTrue(prompt.contains("OrdersPage"))
        XCTAssertTrue(prompt.contains("GET /orders"))
        XCTAssertTrue(prompt.contains("请判断实现是否满足业务需求"))
    }

    func testVerificationPlanUsesProjectSignalsAndCustomCommand() {
        var data = sampleData()
        data.unitTests = UnitTestSummary(
            files: [UnitTestFile(name: "orders.test.ts", path: "frontend/orders.test.ts", framework: "Vitest", testCount: 2, lastModified: nil)],
            frameworks: ["Vitest"],
            totalTests: 2,
            hasCoverage: false
        )

        let plan = VibeRoundService.verificationPlan(for: data, customCommand: "npm test")

        XCTAssertTrue(plan.checks.contains { $0.kind == .command && $0.title == "运行自定义验证命令" && $0.command == "npm test" })
        XCTAssertTrue(plan.checks.contains { $0.kind == .test && $0.title.contains("运行测试") })
        XCTAssertTrue(plan.checks.contains { $0.kind == .manual && $0.title.contains("肉眼验收") })
    }

    private func sampleData() -> ActivityData {
        var data = ActivityData.empty
        data.frontendPages = [
            FrontendPage(
                name: "OrdersPage",
                path: "src/pages/OrdersPage.tsx",
                route: "/orders",
                category: "orders",
                description: "Order management",
                tasks: [],
                componentCount: 2,
                modules: [],
                sharedComponents: [],
                localComponents: ["OrdersTable"],
                hooksUsed: ["useState"],
                fileSize: 1400,
                lastModified: nil
            )
        ]
        data.backendApis = [
            BackendApi(
                name: "listOrders",
                path: "backend/app/api/orders.py",
                method: .get,
                endpoint: "/orders",
                description: "List orders",
                category: "orders",
                completed: true,
                responseFields: 6
            )
        ]
        data.databaseTables = [
            DatabaseTable(
                name: "orders",
                columns: [TableColumn(name: "id", type: "uuid", nullable: false, primaryKey: true, default: nil)],
                relations: []
            )
        ]
        return data
    }
}
