import SwiftUI

/// 书架页：最近阅读 + 收藏列表。
struct BookshelfView: View {
    @State private var response: BookshelfResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                Button("重试") { Task { await load() } }
                    .buttonStyle(.bordered)
            } else if let response {
                if response.favorites.isEmpty && response.recent.isEmpty {
                    ContentUnavailableView(
                        "书架空空",
                        systemImage: "bookmark",
                        description: Text("去发现页找一本喜欢的书吧")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .frame(maxWidth: .infinity, minHeight: 320)
                }

                if !response.recent.isEmpty {
                    Section("最近阅读") {
                        ForEach(response.recent) { item in
                            NavigationLink(value: item.asNovel) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.novelTitle)
                                            .font(serifFont(15, .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(item.chapterTitle)
                                            .font(.footnote)
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(Int(item.scrollPercent * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                            }
                        }
                    }
                }

                Section("我的书架（\(response.favorites.count)）") {
                    ForEach(response.favorites) { favorite in
                        NavigationLink(value: favorite.asNovel) {
                            HStack(spacing: 10) {
                                CachedAsyncImage(url: APIClient.shared.coverURL(novelId: favorite.novelId, updatedAt: favorite.novelUpdatedAt)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    AppTheme.primaryLight
                                }
                                .frame(width: 40, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(favorite.title)
                                        .font(serifFont(15, .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(favorite.author)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                if let percent = favorite.scrollPercent, percent > 0 {
                                    Text("\(Int(percent * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("书架")
        .navigationDestination(for: Novel.self) { NovelDetailView(novel: $0) }
        .scrollContentBackground(.hidden)
        .frostedRowBackground()
        .glassPageBackground()
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        guard APIClient.shared.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let r: BookshelfResponse = try await APIClient.shared.get("/api/bookshelf", auth: true)
            response = r
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 最近阅读 → Novel 转换

private extension RecentItem {
    var asNovel: Novel {
        Novel(
            id: novelId, title: novelTitle, author: "", description: "",
            coverUrl: "", categories: [], status: "", sourceUrl: "",
            chapterCount: 0, remoteChapterCount: 0,
            updateCheckedAt: 0, createdAt: 0, updatedAt: updatedAt
        )
    }
}
