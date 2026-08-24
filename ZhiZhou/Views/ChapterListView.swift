import SwiftUI

/// 章节目录（阅读器内 sheet）：点选跳转章节，打开时自动定位到当前章节。
struct ChapterListView: View {
    let novel: Novel
    let currentOrder: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chapters: [ChapterMeta] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && chapters.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        List(chapters) { chapter in
                            Button {
                                dismiss()
                                onSelect(chapter.order)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("\(chapter.order)")
                                        .font(.caption)
                                        .foregroundStyle(chapter.order == currentOrder ? AppTheme.primary : AppTheme.textMuted)
                                        .frame(width: 34, alignment: .trailing)
                                    Text(chapter.title)
                                        .font(.subheadline)
                                        .foregroundStyle(chapter.order == currentOrder ? AppTheme.primary : AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    if chapter.order == currentOrder {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(chapter.order == currentOrder ? 0.85 : 0.5))
                            .id(chapter.id)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .listRowSeparatorTint(AppTheme.border)
                        .onChange(of: chapters) { _, _ in
                            scrollToCurrent(proxy)
                        }
                        .onAppear {
                            scrollToCurrent(proxy)
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                isLoading = true
                defer { isLoading = false }
                if let r: ChaptersResponse = try? await APIClient.shared.get(
                    "/api/chapters?novelId=\(novel.id)"
                ) {
                    chapters = r.chapters
                }
            }
        }
        .presentationBackground(AppTheme.surfaceWarm)
    }

    /// 打开目录时滚动到当前章节。列表是懒加载的，目标行可能尚未布局，
    /// 故用递增延时重试几次，确保最终定位成功。
    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard chapters.contains(where: { $0.order == currentOrder }) else { return }
        for attempt in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 * Double(attempt)) {
                guard let current = chapters.first(where: { $0.order == currentOrder }) else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(current.id, anchor: .center)
                }
            }
        }
    }
}
