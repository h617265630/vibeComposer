import SwiftUI

struct AiWorkView: View {
    let progress: ProjectProgress

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(progress.aiWork) { item in
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(VibeTheme.accent)
                                    Text(item.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(item.timeAgo)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ForEach(item.evidence) { evidence in
                                    Text("\(evidence.label): \(evidence.detail)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: progress.aiInstruction.title)
                    Text(progress.aiInstruction.prompt)
                        .font(.body)
                        .textSelection(.enabled)
                    Text(progress.aiInstruction.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 360)
            .padding(.trailing, 18)
            .padding(.top, 18)
        }
    }
}
