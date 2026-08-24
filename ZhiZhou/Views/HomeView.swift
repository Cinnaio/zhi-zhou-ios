import SwiftUI

/// 发现页：搜索 + 分类筛选 + 分页加载的小说列表。
struct HomeView: View {
    @State private var novels: [Novel] = []
    @State private var categories: [String] = []
    @State private var selectedCategory: String?
    @State private var search = ""
    @State private var page = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var reloadTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("书海里，遇见好故事")
                    .font(serifFont(22, .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                searchField
                categoryChips

                if isLoading && novels.isEmpty {
                    ProgressView("加载中…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let errorMessage, novels.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.danger)
                        .frame(maxWidth: .infinity)
                    Button("重试") { Task { await reload() } }
                        .buttonStyle(.bordered)
                } else {
                    ForEach(novels) { novel in
                        NavigationLink(value: novel) {
                            NovelCardView(novel: novel)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if novel.id == novels.last?.id { loadMoreIfNeeded() }
                        }
                    }
                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .glassPageBackground()
        .navigationTitle("知舟")
        .navigationDestination(for: Novel.self) { NovelDetailView(novel: $0) }
        .task { await reload() }
        .onChange(of: search) { _, _ in
            reloadTask?.cancel()
            reloadTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await reload()
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            Task { await reload() }
        }
    }

    // MARK: - 子视图

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textSecondary)
            TextField("搜索书名 / 作者", text: $search)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.primary)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(value: nil, label: "全部")
                ForEach(categories, id: \.self) { category in
                    chip(value: category, label: category)
                }
            }
        }
    }

    private func chip(value: String?, label: String) -> some View {
        Button {
            selectedCategory = value
        } label: {
            Text(label)
                .font(.footnote)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(selectedCategory == value ? Color.white : AppTheme.textSecondary)
                .background(
                    selectedCategory == value ? AppTheme.primary : Color.white.opacity(0.7),
                    in: Capsule()
                )
                .overlay(
                    selectedCategory == value ? Color.clear : Color.white.opacity(0.6),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据加载

    func reload() async {
        page = 1
        novels = []
        await fetchPage(1, append: false)
    }

    private func loadMoreIfNeeded() {
        guard !isLoadingMore, page < totalPages else { return }
        Task { await fetchPage(page + 1, append: true) }
    }

    private func fetchPage(_ target: Int, append: Bool) async {
        if target == 1 { isLoading = true } else { isLoadingMore = true }
        defer {
            isLoading = false
            isLoadingMore = false
        }
        do {
            var params: [String: String] = [
                "page": String(target),
                "limit": "20",
                "sort": "updated_at",
                "order": "desc",
            ]
            let trimmed = search.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { params["search"] = trimmed }
            if let selectedCategory { params["category"] = selectedCategory }

            let r: NovelListResponse = try await APIClient.shared.get("/api/novels?" + Self.query(params))
            if append {
                novels += r.novels
            } else {
                novels = r.novels
                if categories.isEmpty { categories = r.availableCategories }
            }
            page = r.page
            totalPages = r.totalPages
            errorMessage = nil
            await CoverPrefetcher.shared.prefetch(r.novels)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func query(_ params: [String: String]) -> String {
        params.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }
        .joined(separator: "&")
    }
}
