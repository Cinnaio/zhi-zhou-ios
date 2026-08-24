import SwiftUI
import UIKit

/// 统一图片缓存（内存 + 磁盘），避免封面在滚动/重访时反复下载。
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

/// 带持久缓存的图片加载视图：优先命中磁盘缓存，未命中才网络下载。
/// 用法与 AsyncImage 一致：`CachedAsyncImage(url:){ image in } placeholder: { }`。
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    @State private var image: UIImage?

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
                return
            }
            if let img = await Self.fetch(url) {
                image = img
            }
        }
    }

    private static func fetch(_ url: URL) async -> UIImage? {
        do {
            let (data, _) = try await ImageCache.session.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
