import SwiftUI

/// 小说详情页：封面信息 + 加入书架 + 章节目录。
struct NovelDetailView: View {
    let novel: Novel
    @EnvironmentObject private var appState: AppState

    @State private var chapters: [ChapterMeta] = []
    @State private var isLoading = false
    @State private var inBookshelf = false
    @State private var errorMessage: String?
    @State private var progress: ReadingProgress?

    var body: some View {
        List {
            Section {
                headerCard
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.danger)
                }
                ForEach(chapters) { chapter in
                    NavigationLink(value: chapter) {
                        HStack {
                            Text(chapter.title)
                                .lineLimit(1)
                            Spacer()
                            if chapter.id == progress?.chapterId {
                                Image(systemName: "bookmark.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.seal)
                            }
                            Text("\(chapter.wordCount) 字")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("章节（\(chapters.count)）")
            }
            .frostedRowBackground()
        }
        .scrollContentBackground(.hidden)
        .glassPageBackground()
        .navigationTitle(novel.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ChapterMeta.self) { chapter in
            ReaderView(novel: novel, chapterOrder: chapter.order)
        }
        .task { await load() }
    }

    // MARK: - 头部玻璃卡片

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: APIClient.shared.coverURL(novelId: novel.id, updatedAt: novel.updatedAt)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        AppTheme.primaryLight
                        Image(systemName: "book.closed")
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                .frame(width: 88, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text(novel.title)
                        .font(serifFont(20, .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(novel.author)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack(spacing: 6) {
                        ForEach(novel.categories, id: \.self) { category in
                            Text(category)
                                .modifier(ThemeTagModifier())
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            // 简介：全宽展示在封面/标题行下方
            Text(novel.description)
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
                .lineLimit(4)

            Button {
                toggleBookshelf()
            } label: {
                Label(inBookshelf ? "已在书架" : "加入书架",
                      systemImage: inBookshelf ? "checkmark.circle.fill" : "plus.circle")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(inBookshelf ? AppTheme.textMuted : AppTheme.primary)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 动作

    private func toggleBookshelf() {
        Task {
            do {
                if inBookshelf {
                    let _: OkEnvelope = try await APIClient.shared.delete(
                        "/api/bookshelf?novelId=\(novel.id)", auth: true
                    )
                    inBookshelf = false
                } else {
                    let body = try APIClient.shared.jsonBody(["novelId": novel.id])
                    let _: OkEnvelope = try await APIClient.shared.post(
                        "/api/bookshelf", body: body, auth: true
                    )
                    inBookshelf = true
                }
            } catch {
                // 静默失败：下次进入会重新同步状态
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r: ChaptersResponse = try await APIClient.shared.get(
                "/api/chapters?novelId=\(novel.id)"
            )
            chapters = r.chapters
            errorMessage = nil

            if appState.user != nil {
                let p: ProgressResponse = try await APIClient.shared.get(
                    "/api/progress?novelId=\(novel.id)", auth: true
                )
                progress = p.progress
                let b: BookshelfResponse = try await APIClient.shared.get(
                    "/api/bookshelf", auth: true
                )
                inBookshelf = b.favorites.contains { $0.novelId == novel.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
