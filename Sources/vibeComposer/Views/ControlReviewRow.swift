import SwiftUI

struct ControlReviewRow: View {
    @EnvironmentObject private var store: ProjectStore
    let item: ControlItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                StatusBadge(text: item.status.label, color: item.status.color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(item.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(item.target)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if item.id.hasPrefix("rule:") {
                    Button {
                        store.openTrackFile()
                    } label: {
                        Label("打开 track", systemImage: "doc.text")
                    }
                } else {
                    Button {
                        store.confirmControlItem(item)
                    } label: {
                        Label("确认完成", systemImage: "checkmark.circle")
                    }

                    Button {
                        store.markControlItemRedo(item)
                    } label: {
                        Label("标记重做", systemImage: "arrow.counterclockwise.circle")
                    }

                    Button {
                        store.openControlItemTarget(item)
                    } label: {
                        Label("打开相关", systemImage: "arrow.up.right.square")
                    }
                }

                Button {
                    store.copyReviewPrompt(for: item)
                } label: {
                    Label("复制指令", systemImage: "doc.on.doc")
                }

                Button {
                    store.refresh()
                } label: {
                    Label("重查", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.vertical, 5)
    }
}
