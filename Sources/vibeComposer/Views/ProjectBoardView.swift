import SwiftUI

struct ProjectBoardView: View {
    let data: ActivityData
    let progress: ProjectProgress
    @State private var selection = "pages"

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selection) {
                Text("页面").tag("pages")
                Text("功能").tag("features")
                Text("组件").tag("components")
            }
            .pickerStyle(.segmented)
            .padding(18)

            ScrollView {
                if selection == "pages" {
                    itemGrid(progress.pages)
                } else if selection == "features" {
                    itemGrid(progress.features)
                } else {
                    componentList
                }
            }
        }
    }

    private func itemGrid(_ items: [TrackableItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
            ForEach(items) { item in
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            StatusBadge(text: item.status.label, color: item.status.color)
                            Spacer()
                            StatusBadge(text: "置信 \(item.confidence.label)", color: item.confidence == .high ? VibeTheme.green : item.confidence == .medium ? VibeTheme.amber : .secondary)
                        }
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(item.businessMeaning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        ForEach(item.evidence.prefix(3)) { evidence in
                            HStack(alignment: .top) {
                                Text(evidence.label)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 58, alignment: .leading)
                                Text(evidence.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
    }

    private var componentList: some View {
        LazyVStack(spacing: 10) {
            ForEach(data.frontendScan.sharedComponents) { component in
                Card {
                    HStack {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(VibeTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(component.name)
                                .font(.headline)
                            Text(component.usedInPages.prefix(4).joined(separator: "、"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(text: "\(component.usageCount) 页面", color: VibeTheme.accent)
                    }
                }
            }
        }
        .padding(18)
    }
}
