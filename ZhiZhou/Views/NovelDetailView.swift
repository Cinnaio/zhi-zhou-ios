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
    @State private var displayNovel: Novel?
    @State private var bookshelfBusy = false
    @State private var showBookshelfError = false

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
        .alert("操作未完成", isPresented: $showBookshelfError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("加入书架失败，请检查网络后重试。")
        }
    }

    // MARK: - 头部玻璃卡片

    /// 展示用小说：优先用服务端补全的完整数据，否则用传入的（最近阅读可能信息不全）
    private var currentNovel: Novel { displayNovel ?? novel }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: APIClient.shared.coverURL(novelId: currentNovel.id, updatedAt: currentNovel.updatedAt)) { image in
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
                    Text(currentNovel.title)
                        .font(serifFont(20, .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(currentNovel.author)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    if !currentNovel.categories.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(currentNovel.categories.prefix(3), id: \.self) { category in
                                Text(category)
                                    .modifier(ThemeTagModifier())
                            }
                            if currentNovel.categories.count > 3 {
                                Text("+\(currentNovel.categories.count - 3)")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            // 简介：全宽展示在封面/标题行下方（无简介时隐藏，避免空白）
            if !currentNovel.description.isEmpty {
                Text(currentNovel.description)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(4)
            }

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
            .disabled(bookshelfBusy)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 动作

    private func toggleBookshelf() {
        guard !bookshelfBusy else { return }
        bookshelfBusy = true
        Task {
            defer { bookshelfBusy = false }
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
                showBookshelfError = true
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 用 id 补全小说完整信息（从"最近阅读"进入时传入对象可能缺作者/分类/封面）
            if let d: NovelDetailResponse = try? await APIClient.shared.get("/api/novels/\(novel.id)") {
                displayNovel = d.novel
            }

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

/// 单本小说详情响应（用于补全"最近阅读"进入时的完整信息）
private struct NovelDetailResponse: Decodable {
    let novel: Novel
}
