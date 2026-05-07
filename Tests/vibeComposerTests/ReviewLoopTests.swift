import XCTest
@testable import vibeComposer

final class ReviewLoopTests: XCTestCase {
    func testGenerationInferenceCreatesRecordsWithoutDuplicatingKnownItems() {
        var data = ActivityData.empty
        data.frontendPages = [
            FrontendPage(
                name: "Dashboard",
                path: "src/pages/Dashboard.tsx",
                route: "/dashboard",
                category: "dashboard",
                description: "",
                tasks: [],
                componentCount: 2,
                modules: [],
                sharedComponents: [],
                localComponents: [],
                hooksUsed: ["useState"],
                fileSize: 1200,
                lastModified: nil
            )
        ]
        data.backendApis = [
            BackendApi(
                name: "listUsers",
                path: "backend/app/api/users.py",
                method: .get,
                endpoint: "/users",
                description: "",
                category: "users",
                completed: true,
                responseFields: 4
            )
        ]
        data.databaseTables = [
            DatabaseTable(
                name: "users",
                columns: [TableColumn(name: "id", type: "uuid", nullable: false, primaryKey: true, default: nil)],
                relations: []
            )
        ]

        let firstPass = GenerationRecordService.inferGenerations(from: data, existing: [])
        let secondPass = GenerationRecordService.inferGenerations(from: data, existing: firstPass)

        XCTAssertEqual(firstPass.count, 3)
        XCTAssertEqual(secondPass.count, 3)
        XCTAssertEqual(secondPass.filter { $0.kind == .page }.count, 1)
        XCTAssertEqual(secondPass.filter { $0.kind == .api }.count, 1)
        XCTAssertEqual(secondPass.filter { $0.kind == .database }.count, 1)
    }

    func testEndingReviewSessionCapturesAcceptedItemsIntoBaseline() {
        let page = FrontendPage(
            name: "Checkout",
            path: "src/pages/Checkout.tsx",
            route: "/checkout",
            category: "checkout",
            description: "",
            tasks: [],
            componentCount: 3,
            modules: [],
            sharedComponents: ["Button"],
            localComponents: ["CheckoutForm"],
            hooksUsed: ["useState"],
            fileSize: 2400,
            lastModified: nil
        )
        var data = ActivityData.empty.replacing(frontendPages: [page])
        var state = UserControlState.empty
        let item = ProgressDeriver.derive(from: data).pages[0]
        let session = ReviewService.startReviewSession(in: &state, items: [item])

        ReviewService.reviewItem(in: &state, itemId: session.items[0].id, decision: .confirmed, notes: "视觉和流程都符合")
        data.controlState = state
        ReviewService.endReviewSession(in: &state, currentData: data)

        XCTAssertEqual(state.reviewSessions.count, 1)
        XCTAssertNil(state.currentSession)
        XCTAssertEqual(state.decisions[item.id]?.decision, .confirmed)
        XCTAssertNotNil(state.baseline?.itemFingerprints[item.id])
    }

    func testRejectedReviewItemIsNotCapturedIntoBaseline() {
        let table = DatabaseTable(
            name: "orders",
            columns: [TableColumn(name: "id", type: "uuid", nullable: false, primaryKey: true, default: nil)],
            relations: []
        )
        var data = ActivityData.empty.replacing(databaseTables: [table])
        var state = UserControlState.empty
        let item = ProgressDeriver.derive(from: data).features.first { $0.id == "feature:database" }!
        let session = ReviewService.startReviewSession(in: &state, items: [item])

        ReviewService.reviewItem(in: &state, itemId: session.items[0].id, decision: .redo, notes: "缺少订单状态")
        data.controlState = state
        ReviewService.endReviewSession(in: &state, currentData: data)

        XCTAssertEqual(state.decisions[item.id]?.decision, .redo)
        XCTAssertNil(state.baseline?.itemFingerprints[item.id])
    }

    func testInitialScanItemsAreReviewableBeforeBaselineExists() {
        var data = ActivityData.empty
        data.frontendPages = [
            FrontendPage(
                name: "Home",
                path: "src/pages/Home.tsx",
                route: "/",
                category: "home",
                description: "",
                tasks: [],
                componentCount: 1,
                modules: [],
                sharedComponents: [],
                localComponents: ["Hero"],
                hooksUsed: [],
                fileSize: 900,
                lastModified: nil
            )
        ]

        let reviewItems = ReviewService.itemsNeedingReview(from: data)

        XCTAssertEqual(reviewItems.map(\.id), ["page:src/pages/Home.tsx"])
    }

    func testControlStateAfterScanPersistsInferredGenerationRecords() {
        var data = ActivityData.empty
        data.frontendPages = [
            FrontendPage(
                name: "Settings",
                path: "src/pages/Settings.tsx",
                route: "/settings",
                category: "settings",
                description: "",
                tasks: [],
                componentCount: 1,
                modules: [],
                sharedComponents: [],
                localComponents: ["SettingsForm"],
                hooksUsed: [],
                fileSize: 1100,
                lastModified: nil
            )
        ]

        let firstState = ReviewService.controlStateAfterScan(data, previousState: .empty)
        var rescanned = data
        rescanned.controlState = firstState
        let secondState = ReviewService.controlStateAfterScan(rescanned, previousState: firstState)

        XCTAssertEqual(firstState.generations.count, 1)
        XCTAssertEqual(firstState.generations.first?.title, "Settings")
        XCTAssertEqual(secondState.generations.count, 1)
    }

    func testRequirementDraftKeepsBusinessValueAndAcceptanceCriteria() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let requirement = ReviewService.makeRequirement(
            title: "用户可以完成支付",
            userValue: "买家能从购物车进入支付并看到结果",
            acceptanceText: """
            能提交支付表单

            支付失败时显示错误
            成功后跳转订单页
            """,
            updatedAt: updatedAt
        )

        XCTAssertEqual(requirement.title, "用户可以完成支付")
        XCTAssertEqual(requirement.userValue, "买家能从购物车进入支付并看到结果")
        XCTAssertEqual(requirement.acceptanceCriteria, ["能提交支付表单", "支付失败时显示错误", "成功后跳转订单页"])
        XCTAssertEqual(requirement.priority, .medium)
        XCTAssertEqual(requirement.status, .planned)
        XCTAssertEqual(requirement.updatedAt, updatedAt)
    }

    func testAlignmentReportConnectsRequirementToImplementationEvidence() {
        let requirement = ProjectRequirement(
            id: "orders-requirement",
            title: "用户可以管理订单",
            userValue: "运营人员能查看订单列表和订单状态",
            acceptanceCriteria: ["能打开订单页面", "能通过 API 读取订单", "订单数据被保存"],
            priority: .medium,
            status: .planned,
            updatedAt: Date()
        )
        var data = ActivityData.empty
        data.controlState.requirements = [requirement]
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
        let item = ProgressDeriver.derive(from: data).features.first { $0.id == "requirement:orders-requirement" }!

        let report = ReviewService.alignmentReport(for: item, in: data)

        XCTAssertEqual(report.requirementTitle, "用户可以管理订单")
        XCTAssertEqual(report.acceptanceCriteria.count, 3)
        XCTAssertEqual(report.matchedPages.map(\.title), ["OrdersPage"])
        XCTAssertEqual(report.matchedApis.map(\.title), ["GET /orders"])
        XCTAssertEqual(report.matchedTables.map(\.title), ["orders"])
        XCTAssertTrue(report.relatedFiles.contains("src/pages/OrdersPage.tsx"))
        XCTAssertTrue(report.relatedFiles.contains("backend/app/api/orders.py"))
        XCTAssertTrue(report.missingSignals.isEmpty)
    }

    func testAlignmentReportSurfacesMissingRequirementContext() {
        var data = ActivityData.empty
        data.backendApis = [
            BackendApi(
                name: "createPayment",
                path: "backend/app/api/payments.py",
                method: .post,
                endpoint: "/payments",
                description: "Create payment",
                category: "payments",
                completed: true,
                responseFields: 4
            )
        ]
        let item = ProgressDeriver.derive(from: data).features.first { $0.id == "feature:api:payments" }!

        let report = ReviewService.alignmentReport(for: item, in: data)

        XCTAssertNil(report.requirementTitle)
        XCTAssertTrue(report.missingSignals.contains("未找到直接关联的业务需求"))
        XCTAssertEqual(report.matchedApis.map(\.title), ["POST /payments"])
    }

    func testRedoPromptIncludesRequirementEvidenceNotesAndVerification() {
        let item = TrackableItem(
            id: "requirement:checkout",
            title: "用户可以完成支付",
            kind: "feature",
            status: .needsReview,
            confidence: .medium,
            confidenceReason: "匹配到部分实现线索",
            businessMeaning: "买家能从购物车进入支付并看到结果",
            lastTouched: nil,
            evidence: [Evidence(label: "实现线索", detail: "页面 /checkout、接口 POST /payments")]
        )
        let report = AlignmentReport(
            targetId: item.id,
            targetTitle: item.title,
            requirementTitle: "用户可以完成支付",
            requirementValue: "买家能从购物车进入支付并看到结果",
            acceptanceCriteria: ["能提交支付表单", "支付失败时显示错误"],
            matchedPages: [AlignmentEvidence(title: "Checkout", detail: "/checkout", path: "src/pages/Checkout.tsx")],
            matchedApis: [AlignmentEvidence(title: "POST /payments", detail: "backend/app/api/payments.py", path: "backend/app/api/payments.py")],
            matchedTables: [],
            relatedFiles: ["src/pages/Checkout.tsx", "backend/app/api/payments.py"],
            missingSignals: ["未找到支付结果页面"],
            riskSignals: ["验收者标记支付失败态不完整"],
            recommendation: "先补齐支付失败态和结果页。"
        )

        let prompt = ReviewService.redoPrompt(for: item, report: report, notes: "失败时没有错误提示")

        XCTAssertTrue(prompt.contains("用户可以完成支付"))
        XCTAssertTrue(prompt.contains("失败时没有错误提示"))
        XCTAssertTrue(prompt.contains("src/pages/Checkout.tsx"))
        XCTAssertTrue(prompt.contains("未找到支付结果页面"))
        XCTAssertTrue(prompt.contains("请按最小修改完成重做"))
        XCTAssertTrue(prompt.contains("验证方式"))
    }
}
