import SwiftUI

struct TechnicalDetailsView: View {
    let data: ActivityData
    @State private var tab = "stack"
    @State private var databaseViewMode = "er"

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("技术栈").tag("stack")
                Text("API").tag("api")
                Text("数据库").tag("database")
                Text("测试").tag("tests")
                Text("规范").tag("standards")
                Text("质量").tag("quality")
                Text("结构").tag("structure")
            }
            .pickerStyle(.segmented)
            .padding(18)

            ScrollView {
                switch tab {
                case "stack": stackView
                case "api": apiView
                case "database": databaseSection
                case "tests": testsView
                case "standards": standardsView
                case "quality": qualityView
                default: structureView
                }
            }
        }
    }

    private var stackView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
            ForEach(data.techStack) { stack in
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: stack.category)
                        ForEach(stack.items) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text(item.version ?? item.description ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
    }

    private var apiView: some View {
        LazyVStack(spacing: 10) {
            ForEach(data.backendApis) { api in
                Card {
                    HStack {
                        StatusBadge(text: api.method.rawValue, color: VibeTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(api.endpoint)
                                .font(.headline.monospaced())
                            Text("\(api.name) · \(api.path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(text: api.completed ? "完成" : "待补", color: api.completed ? VibeTheme.green : VibeTheme.amber)
                    }
                }
            }
        }
        .padding(18)
    }

    private var databaseSection: some View {
        VStack(spacing: 0) {
            // 视图切换
            HStack(spacing: 12) {
                Text("数据库")
                    .font(.headline)
                Spacer()
                Picker("", selection: $databaseViewMode) {
                    Text("ER 图").tag("er")
                    Text("列表").tag("list")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            if databaseViewMode == "er" {
                DatabaseERView(tables: data.databaseTables)
            } else {
                DatabaseListView(tables: data.databaseTables)
            }
        }
    }

    private var databaseView: some View {
        DatabaseListView(tables: data.databaseTables)
    }

    private var testsView: some View {
        LazyVStack(spacing: 10) {
            MetricTile(title: "测试总数", value: "\(data.unitTests.totalTests)", detail: data.unitTests.frameworks.joined(separator: "、"), symbol: "testtube.2")
            ForEach(data.unitTests.files) { file in
                Card {
                    HStack {
                        Text(file.path)
                            .lineLimit(1)
                        Spacer()
                        StatusBadge(text: file.framework, color: VibeTheme.accent)
                        Text("\(file.testCount)")
                            .font(.caption.monospaced())
                    }
                }
            }
        }
        .padding(18)
    }

    private var standardsView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Code Standards")
                    Text(data.codeStandards.isConfigured ? "已配置" : "未识别")
                    ForEach(data.codeStandards.linters + data.codeStandards.formatters) { config in
                        Text("\(config.name) · \(config.path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Strict Mode: \(data.codeStandards.hasStrictMode ? "on" : "off")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "UI Standards")
                    Text(data.uiStandards.cssFramework)
                    Text(data.uiStandards.componentLibs.joined(separator: "、").nonEmpty ?? "未识别组件库")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(data.uiStandards.tokens.prefix(12)) { token in
                        Text("--\(token.name): \(token.value)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
    }

    private var qualityView: some View {
        LazyVStack(spacing: 10) {
            MetricTile(title: "质量分", value: "\(data.codeQuality.summary.score)", detail: "\(data.codeQuality.summary.total) checks", symbol: "gauge.with.dots.needle.67percent")
            ForEach(data.codeQuality.checks) { check in
                Card {
                    HStack(alignment: .top) {
                        StatusBadge(text: check.severity.label, color: check.severity == .error ? VibeTheme.red : check.severity == .warning ? VibeTheme.amber : VibeTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(check.message)
                                .font(.subheadline.weight(.medium))
                            Text("\(check.file)\(check.line.map { ":\($0)" } ?? "")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            if let suggestion = check.suggestion {
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(18)
    }

    private var structureView: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(flatten(data.projectStructure)) { node in
                HStack {
                    Text(String(repeating: "  ", count: node.depth))
                        .font(.caption.monospaced())
                    Image(systemName: node.type == .folder ? "folder" : "doc.text")
                        .foregroundStyle(node.type == .folder ? VibeTheme.amber : .secondary)
                    Text(node.name)
                    Spacer()
                }
                .font(.caption)
                .padding(.vertical, 2)
            }
        }
        .padding(18)
    }

    private func flatten(_ nodes: [TreeNode]) -> [TreeNode] {
        nodes.flatMap { [$0] + flatten($0.children) }
    }
}
