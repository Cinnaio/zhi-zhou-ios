import SwiftUI
import UIKit

/// 统一图片缓存（内存 + 磁盘），避免封面在滚动/重访时反复下载。
/// `/api/cover` 返回 `Cache-Control: public, max-age=86400`，故磁盘缓存可命中一整天。
enum ImageCache {
    /// 大容量缓存：256MB 内存 + 512MB 磁盘，长列表滚动封面不再被逐出
    static let sharedCache: URLCache = {
        URLCache(memoryCapacity: 256 * 1024 * 1024,
                 diskCapacity: 512 * 1024 * 1024)
    }()

    /// 图片专用会话：命中缓存直接返回，未命中才走网络（较短超时，避免长时间卡占位图）
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = sharedCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        return URLSession(configuration: config)
    }()
}

/// 封面预取：限并发（默认 4）并按 URL 去重，避免快速翻页时后台请求堆爆。
actor CoverPrefetcher {
    static let shared = CoverPrefetcher()

    private var active = 0
    private var queued: [URL] = []
    private var seen: Set<String> = []
    private let maxConcurrent = 4

    func prefetch(_ items: [Novel]) {
        for novel in items {
            guard let url = APIClient.shared.coverURL(novelId: novel.id, updatedAt: novel.updatedAt) else { continue }
            let key = url.absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            queued.append(url)
        }
        pump()
    }

    private func pump() {
        while active < maxConcurrent, !queued.isEmpty {
            let url = queued.removeFirst()
            active += 1
            Task {
                _ = try? await ImageCache.session.data(from: url)
                active -= 1
                pump()
            }
        }
    }
}

/// 带持久缓存的图片加载视图：优先命中磁盘缓存，未命中才网络下载。
/// 用法与 AsyncImage 一致：`CachedAsyncImage(url:){ image in } placeholder: { }`。
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    @State private var image: UIImage?
    @State private var loadedKey: String?

    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    init(url: URL?,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                loadedKey = nil
                return
            }
            let key = url.absoluteString
            // 同一地址已加载：保留现有图，避免滚回时闪占位
            if loadedKey == key, image != nil { return }
            // 地址变化：清掉旧图，避免错图一闪
            image = nil
            if let img = await Self.fetch(url) {
                image = img
                loadedKey = key
            }
        }
    }

    /// 取图：4xx/5xx 直接返回 nil（不重试），仅传输错误重试一次。
    private static func fetch(_ url: URL) async -> UIImage? {
        do {
            let (data, response) = try await ImageCache.session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            return UIImage(data: data)
        } catch {
            guard let (data, _) = try? await ImageCache.session.data(from: url) else { return nil }
            return UIImage(data: data)
        }
    }
}
