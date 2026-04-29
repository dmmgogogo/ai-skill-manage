import SwiftUI

struct AnalysisDrawer: View {
    @Bindable var analysisStore: AnalysisStore
    let item: SkillItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            if let date = analysisStore.analyzedAt {
                Divider()
                footer(date: date)
            }
        }
        .frame(width: 360)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Label("AI 分析", systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if analysisStore.result != nil || analysisStore.errorMessage != nil {
                Button {
                    Task { await analysisStore.analyze(item: item, forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(analysisStore.isAnalyzing)
                .help("重新分析")
            }
            Button {
                analysisStore.showDrawer = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if analysisStore.isAnalyzing {
            VStack(spacing: 10) {
                ProgressView()
                Text("分析中…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 40)
        } else if let error = analysisStore.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        } else if let text = analysisStore.result {
            ScrollView {
                let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                Text((try? AttributedString(markdown: text, options: opts)) ?? AttributedString(text))
                    .font(.system(size: 13))
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .textSelection(.enabled)
            }
        } else {
            Text("点击工具栏「分析」按钮开始分析此 skill")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
        }
    }

    private func footer(date: Date) -> some View {
        Text("分析于 \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}
