import SwiftUI

// MARK: - 滚动位置/内容尺寸的 PreferenceKey

struct ReaderContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct ReaderOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 阅读器（核心）：滚动式阅读、字号/行距/主题/字体设置、进度双向同步、上下章切换。
struct ReaderView: View {
    let novel: Novel
    @State var chapterOrder: Int

    @EnvironmentObject private var settings: ReaderSettingsStore

    @State private var chapter: ChapterFull?
    @State private var chapterCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var contentSize: CGSize = .zero
    @State private var viewportHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPercent: Double = 0
    @State private var restorePercent: Double = 0
    @State private var didRestore = false
    @State private var restoreSpacer: CGFloat = 0
    @State private var saveTask: Task<Void, Never>?

    var totalOrderCount: Int {
        max(chapterCount, novel.chapterCount)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: settings.lineSpacing) {
                        if restoreSpacer > 0 {
                            Color.clear
                                .frame(height: restoreSpacer)
                                .id("restore")
                        }
                        if isLoading && chapter == nil {
                            ProgressView("加载中…")
                                .foregroundStyle(settings.textColor)
                                .frame(maxWidth: .infinity, minHeight: 300)
                        } else if let errorMessage, chapter == nil {
                            VStack(spacing: 12) {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.danger)
                                Button("重试") { Task { await load() } }
                                    .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        } else if let chapter {
                            Text(chapter.title)
                                .font(settings.titleFont)
                                .foregroundStyle(settings.textColor)
                                .padding(.bottom, 8)
                            ForEach(paragraphs(of: chapter), id: \.self) { paragraph in
                                Text(paragraph)
                                    .font(settings.bodyFont)
                                    .lineSpacing(settings.lineSpacing)
                                    .foregroundStyle(settings.textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 80)
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .preference(key: ReaderContentSizeKey.self, value: g.size)
                                .preference(key: ReaderOffsetKey.self, value: g.frame(in: .named("readerScroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "readerScroll")
                .background(settings.backgroundColor)
                .onPreferenceChange(ReaderContentSizeKey.self) { size in
                    contentSize = size
                    applyRestore()
                }
                .onPreferenceChange(ReaderOffsetKey.self) { value in
                    scrollOffset = value
                    updatePercent()
                }
                .onAppear { viewportHeight = geo.size.height }
                .onChange(of: geo.size.height) { _, height in
                    viewportHeight = height
                }
                .onChange(of: restoreSpacer) { _, height in
                    if height > 0 {
                        proxy.scrollTo("restore", anchor: .top)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showTOC = true } label: { Image(systemName: "list.bullet") }
                Button { showSettings = true } label: { Image(systemName: "textformat.size") }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button { go(to: chapterOrder - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(chapterOrder <= 1)
                Spacer()
                Text("\(chapterOrder)/\(totalOrderCount)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
                Button { go(to: chapterOrder + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(chapterOrder >= totalOrderCount)
            }
        }
        .toolbarBackground(settings.backgroundColor, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showTOC) {
            ChapterListView(novel: novel, currentOrder: chapterOrder) { order in
                go(to: order)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
                .presentationDetents([.medium])
        }
        .task { await load() }
        .onChange(of: chapterOrder) { _, _ in
            didRestore = false
            restoreSpacer = 0
            restorePercent = 0
            scrollPercent = 0
            Task { await load() }
        }
        .onDisappear {
            // 离开阅读器时尽力同步一次进度
            let body = progressBody()
            if let body {
                Task {
                    try? await APIClient.shared.requestVoid("POST", "/api/progress", body: body, auth: true)
                }
            }
        }
    }

    // MARK: - 加载

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 服务端正文接口为 /api/chapters/{chapterId}：先用目录的 order 反查章节 id，再取正文。
            let list: ChaptersResponse = try await APIClient.shared.get(
                "/api/chapters?novelId=\(novel.id)"
            )
            chapterCount = list.chapters.count
            guard let meta = list.chapters.first(where: { $0.order == chapterOrder }) else {
                errorMessage = "未找到第 \(chapterOrder) 章"
                return
            }

            let r: ChapterResponse = try await APIClient.shared.get(
                "/api/chapters/\(meta.id)"
            )
            chapter = r.chapter
            errorMessage = nil

            // 恢复阅读进度
            if !didRestore, APIClient.shared.isAuthenticated {
                let p: ProgressResponse = try await APIClient.shared.get(
                    "/api/progress?novelId=\(novel.id)", auth: true
                )
                if let prog = p.progress, prog.chapterId == r.chapter.id, prog.scrollPercent > 0 {
                    restorePercent = prog.scrollPercent
                    didRestore = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        applyRestore()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyRestore() {
        guard didRestore, chapter != nil else { return }
        let maxOffset = max(contentSize.height - viewportHeight, 0)
        guard maxOffset > 1 else { return }
        let target = restorePercent * maxOffset
        if target > 1 {
            restoreSpacer = target
        }
    }

    // MARK: - 进度

    private func updatePercent() {
        let maxOffset = max(contentSize.height - viewportHeight, 0)
        guard maxOffset > 0 else { return }
        scrollPercent = min(1, max(0, -scrollOffset / maxOffset))
        debounceSaveProgress()
    }

    private func debounceSaveProgress() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, APIClient.shared.isAuthenticated else { return }
            if let body = progressBody() {
                try? await APIClient.shared.requestVoid("POST", "/api/progress", body: body, auth: true)
            }
        }
    }

    private func progressBody() -> Data? {
        guard let chapter else { return nil }
        let body = SaveProgressBody(
            novelId: novel.id,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            chapterOrder: chapter.order,
            scrollPercent: scrollPercent,
            pageMode: "scroll",
            clientUpdatedAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        return try? APIClient.shared.jsonBody(body)
    }

    // MARK: - 章节切换

    private func go(to order: Int) {
        guard order >= 1, order <= totalOrderCount else { return }
        chapterOrder = order
    }

    // MARK: - 段落切分

    private func paragraphs(of chapter: ChapterFull) -> [String] {
        let byBlankLine = chapter.content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if byBlankLine.count > 1 { return byBlankLine }
        return chapter.content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
