import SwiftUI

/// 章节目录（阅读器内 sheet）：点选跳转章节。
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
                if isLoading {
                    ProgressView()
                } else {
                    List(chapters) { chapter in
                        Button {
                            dismiss()
                            onSelect(chapter.order)
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .foregroundStyle(chapter.order == currentOrder ? AppTheme.primary : Color.primary)
                                Spacer()
                                if chapter.order == currentOrder {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.primary)
                                }
                            }
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
}
