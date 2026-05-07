import SwiftUI

// MARK: - ER 图风格的数据库视图

struct DatabaseERView: View {
    let tables: [DatabaseTable]
    @State private var selectedTable: DatabaseTable?
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            Divider()

            // ER 图主区域
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // 表格节点
                    tablesLayout
                }
                .padding(40)
                .scaleEffect(zoomScale)
                .offset(offset)
            }
            .background(.white)
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 16) {
            Text("数据库 ER 图")
                .font(.headline)

            Spacer()

            // 统计
            HStack(spacing: 12) {
                statBadge("\(tables.count) 表", VibeTheme.accent)
                statBadge("\(totalColumns) 字段", VibeTheme.amber)
                statBadge("\(totalRelations) 关联", VibeTheme.green)
            }

            Divider()
                .frame(height: 20)

            // 缩放控制
            HStack(spacing: 8) {
                Button {
                    withAnimation { zoomScale = max(0.5, zoomScale - 0.2) }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption.monospaced())
                    .frame(width: 44)

                Button {
                    withAnimation { zoomScale = min(2.0, zoomScale + 0.2) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Button {
                    withAnimation {
                        zoomScale = 1.0
                        offset = .zero
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }

    private func statBadge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - 表格布局

    private var tablesLayout: some View {
        let columns = 3
        let columnWidth: CGFloat = 280
        let rowHeight: CGFloat = 320
        let spacing: CGFloat = 40

        return ZStack {
            // 连接线
            ForEach(tables) { table in
                relationLines(for: table)
            }

            // 表格卡片
            ForEach(Array(tables.enumerated()), id: \.element.id) { index, table in
                let col = index % columns
                let row = index / columns
                let x = CGFloat(col) * (columnWidth + spacing)
                let y = CGFloat(row) * (rowHeight + spacing)

                ERTableCard(table: table, isSelected: selectedTable?.id == table.id)
                    .frame(width: columnWidth)
                    .position(x: x + columnWidth / 2 + 40, y: y + rowHeight / 2 + 40)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTable = selectedTable?.id == table.id ? nil : table
                        }
                    }
            }
        }
        .frame(
            width: CGFloat((tables.count - 1) / 3 + 1) * (columnWidth + spacing) + 80,
            height: CGFloat((tables.count - 1) / 3 + 1) * (rowHeight + spacing) + 80
        )
    }

    // MARK: - 关系连接线

    @ViewBuilder
    private func relationLines(for table: DatabaseTable) -> some View {
        ForEach(table.relations) { relation in
            if let targetTable = tables.first(where: { $0.name == relation.toTable }) {
                RelationLine(
                    fromTable: table.name,
                    toTable: targetTable.name,
                    fromColumn: relation.fromColumn,
                    toColumn: relation.toColumn,
                    relationType: relation.type
                )
            }
        }
    }

    // MARK: - 计算属性

    private var totalColumns: Int {
        tables.reduce(0) { $0 + $1.columns.count }
    }

    private var totalRelations: Int {
        tables.reduce(0) { $0 + $1.relations.count }
    }
}

// MARK: - ER 表格卡片

struct ERTableCard: View {
    let table: DatabaseTable
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 表头
            header

            Divider()

            // 字段列表
            columnsList
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? VibeTheme.accent : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? VibeTheme.accent.opacity(0.2) : Color.clear, radius: 8)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "table")
                .font(.caption)
                .foregroundStyle(VibeTheme.accent)

            Text(table.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text("\(table.columns.count)")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(VibeTheme.accent.opacity(0.2))
                .foregroundStyle(VibeTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.92, green: 0.92, blue: 0.93))
    }

    private var columnsList: some View {
        VStack(spacing: 0) {
            ForEach(table.columns.prefix(10)) { column in
                columnRow(column)

                if column.id != table.columns.prefix(10).last?.id {
                    Divider()
                        .padding(.leading, 12)
                }
            }

            if table.columns.count > 10 {
                HStack {
                    Text("+\(table.columns.count - 10) more...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.94, green: 0.94, blue: 0.95))
            }
        }
    }

    private func columnRow(_ column: TableColumn) -> some View {
        HStack(spacing: 8) {
            // 主键标记
            if column.primaryKey {
                Image(systemName: "key.fill")
                    .font(.caption2)
                    .foregroundStyle(VibeTheme.amber)
            } else if isForeignKey(column.name) {
                Image(systemName: "link")
                    .font(.caption2)
                    .foregroundStyle(VibeTheme.green)
            } else {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 字段名
            Text(column.name)
                .font(.caption.monospaced())
                .lineLimit(1)

            Spacer()

            // 类型
            Text(formatType(column.type))
                .font(.caption2)
                .foregroundStyle(.secondary)

            // 约束标记
            HStack(spacing: 4) {
                if !column.nullable {
                    Text("NN")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(VibeTheme.red)
                }
            }
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(column.primaryKey ? Color(red: 0.12, green: 0.10, blue: 0.06) : Color.clear)
    }

    private func isForeignKey(_ columnName: String) -> Bool {
        table.relations.contains { $0.fromColumn == columnName }
    }

    private func formatType(_ type: String) -> String {
        type.lowercased()
            .replacingOccurrences(of: "character varying", with: "varchar")
            .replacingOccurrences(of: "integer", with: "int")
            .replacingOccurrences(of: "timestamp without time zone", with: "timestamp")
    }
}

// MARK: - 关系连接线

struct RelationLine: View {
    let fromTable: String
    let toTable: String
    let fromColumn: String
    let toColumn: String
    let relationType: String

    var body: some View {
        // 简化的连接线表示
        // 实际实现需要计算两个表格的位置
        EmptyView()
    }
}

// MARK: - 数据库详情侧边栏

struct DatabaseDetailPanel: View {
    let table: DatabaseTable

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "table")
                    .font(.title2)
                    .foregroundStyle(VibeTheme.accent)
                Text(table.name)
                    .font(.title2.weight(.semibold))
            }

            Divider()

            // 统计
            HStack(spacing: 20) {
                statItem("字段", "\(table.columns.count)")
                statItem("关联", "\(table.relations.count)")
            }

            // 字段列表
            VStack(alignment: .leading, spacing: 8) {
                Text("字段")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(table.columns) { column in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(column.name)
                                    .font(.caption.monospaced().weight(.medium))
                                if column.primaryKey {
                                    Text("PK")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(VibeTheme.amber)
                                }
                            }
                            Text(column.type)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if !column.nullable {
                            Text("NOT NULL")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(VibeTheme.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // 关联
            if !table.relations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("关联")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(table.relations) { relation in
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(VibeTheme.green)
                            Text(relation.fromColumn)
                                .font(.caption.monospaced())
                            Text("→")
                                .foregroundStyle(.tertiary)
                            Text(relation.toTable)
                                .font(.caption.monospaced().weight(.medium))
                                .foregroundStyle(VibeTheme.accent)
                            Text(".\(relation.toColumn)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 280)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(red: 0.92, green: 0.92, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - 简化版数据库列表（备选视图）

struct DatabaseListView: View {
    let tables: [DatabaseTable]
    @State private var expandedTables: Set<String> = []

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(tables) { table in
                DatabaseTableSection(
                    table: table,
                    isExpanded: expandedTables.contains(table.id),
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedTables.contains(table.id) {
                                expandedTables.remove(table.id)
                            } else {
                                expandedTables.insert(table.id)
                            }
                        }
                    }
                )
            }
        }
        .padding(18)
    }
}

struct DatabaseTableSection: View {
    let table: DatabaseTable
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 表头
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: "table")
                        .font(.title3)
                        .foregroundStyle(VibeTheme.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(table.name)
                            .font(.headline)
                        Text("\(table.columns.count) 字段 · \(table.relations.count) 关联")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(red: 0.92, green: 0.92, blue: 0.93))
            }
            .buttonStyle(.plain)

            // 展开内容
            if isExpanded {
                VStack(spacing: 0) {
                    // 字段表格
                    HStack(spacing: 0) {
                        // 表头
                        Text("字段名")
                            .font(.caption.weight(.semibold))
                            .frame(width: 140, alignment: .leading)
                        Text("类型")
                            .font(.caption.weight(.semibold))
                            .frame(width: 100, alignment: .leading)
                        Text("约束")
                            .font(.caption.weight(.semibold))
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.94, green: 0.94, blue: 0.95))

                    Divider()

                    // 字段行
                    ForEach(table.columns) { column in
                        HStack(spacing: 0) {
                            HStack(spacing: 6) {
                                if column.primaryKey {
                                    Image(systemName: "key.fill")
                                        .font(.caption2)
                                        .foregroundStyle(VibeTheme.amber)
                                }
                                Text(column.name)
                                    .font(.caption.monospaced())
                            }
                            .frame(width: 140, alignment: .leading)

                            Text(formatType(column.type))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)

                            HStack(spacing: 4) {
                                if column.primaryKey {
                                    Text("PK")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(VibeTheme.amber)
                                }
                                if !column.nullable {
                                    Text("NN")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(VibeTheme.red)
                                }
                            }
                            .frame(width: 80, alignment: .leading)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(column.primaryKey ? Color(red: 0.10, green: 0.08, blue: 0.04) : Color.clear)

                        if column.id != table.columns.last?.id {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }

                    // 关联信息
                    if !table.relations.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("外键关联")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(table.relations) { relation in
                                HStack(spacing: 8) {
                                    Text(relation.fromColumn)
                                        .font(.caption.monospaced())
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(VibeTheme.green)
                                    Text(relation.toTable)
                                        .font(.caption.monospaced().weight(.medium))
                                        .foregroundStyle(VibeTheme.accent)
                                    Text(".\(relation.toColumn)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.06, green: 0.08, blue: 0.06))
                    }
                }
                .background(Color(red: 0.07, green: 0.07, blue: 0.08))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08))
        )
    }
    
    private func formatType(_ type: String) -> String {
        type.lowercased()
            .replacingOccurrences(of: "character varying", with: "varchar")
            .replacingOccurrences(of: "integer", with: "int")
            .replacingOccurrences(of: "timestamp without time zone", with: "timestamp")
    }
}
