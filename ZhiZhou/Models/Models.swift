import Foundation

// MARK: - 服务端模型
// 字段与知舟仓库 shared/types.ts 一一对应（API 返回 camelCase，JSONDecoder 直接解码）。

struct User: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let displayName: String
    let role: String
    let status: String
    let createdAt: Int64
    let updatedAt: Int64
    let lastLoginAt: Int64?
    let bio: String?
    let avatarUrl: String?

    var displayBio: String {
        let value = bio ?? ""
        return value.isEmpty ? "这个人很懒，什么都没写。" : value
    }
}

struct Novel: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let description: String
    let coverUrl: String
    let categories: [String]
    let status: String
    let sourceUrl: String
    let chapterCount: Int
    let remoteChapterCount: Int
    let updateCheckedAt: Int64
    let createdAt: Int64
    let updatedAt: Int64
}

struct NovelListResponse: Codable {
    let novels: [Novel]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
    let hasMore: Bool
    let availableCategories: [String]
}

struct ChapterMeta: Codable, Identifiable, Hashable {
    let id: String
    let novelId: String
    let title: String
    let order: Int
    let wordCount: Int
    let sourceUrl: String
    let createdAt: Int64
}

struct ChapterFull: Codable {
    let id: String
    let novelId: String
    let title: String
    let order: Int
    let wordCount: Int
    let sourceUrl: String
    let createdAt: Int64
    let content: String
}

struct ChaptersResponse: Codable { let chapters: [ChapterMeta] }
struct ChapterResponse: Codable { let chapter: ChapterFull }

struct LoginResponse: Codable { let user: User; let token: String }
struct MeResponse: Codable { let user: User }
struct RegisterStatusResponse: Codable { let mode: String }
struct HealthResponse: Codable { let ok: Bool; let name: String }

/// GET /api/progress?novelId= 的返回（progress 可能为 null）
struct ReadingProgress: Codable {
    let novelId: String
    let chapterId: String
    let scrollPercent: Double
    let updatedAt: Int64
}

struct ProgressResponse: Codable { let progress: ReadingProgress? }

/// POST /api/progress 的请求体（与 web/src/lib/api.ts saveOnExit 对齐）
struct SaveProgressBody: Codable {
    let novelId: String
    let chapterId: String
    let chapterTitle: String
    let chapterOrder: Int
    let scrollPercent: Double
    let pageMode: String
    let clientUpdatedAt: Int64
}

struct BookshelfResponse: Codable {
    let favorites: [FavoriteItem]
    let recent: [RecentItem]
    let thoughts: [ThoughtItem]
}

struct FavoriteItem: Codable, Hashable, Identifiable {
    var id: String { novelId }
    let novelId: String
    let title: String
    let author: String
    let description: String
    let status: String
    let chapterCount: Int
    let remoteChapterCount: Int
    let novelUpdatedAt: Int64
    let chapterId: String?
    let chapterTitle: String?
    let chapterOrder: Int?
    let scrollPercent: Double?
    let progressUpdatedAt: Int64?

    var asNovel: Novel {
        Novel(
            id: novelId, title: title, author: author, description: description,
            coverUrl: "", categories: [], status: status, sourceUrl: "",
            chapterCount: chapterCount, remoteChapterCount: remoteChapterCount,
            updateCheckedAt: 0, createdAt: 0, updatedAt: novelUpdatedAt
        )
    }
}

struct RecentItem: Codable, Hashable, Identifiable {
    var id: String { novelId + ":" + chapterId }
    let novelId: String
    let chapterId: String
    let novelTitle: String
    let chapterTitle: String
    let chapterOrder: Int
    let scrollPercent: Double
    let updatedAt: Int64
}

struct ThoughtItem: Codable, Identifiable {
    let id: String
    let novelId: String
    let chapterId: String
    let novelTitle: String?
    let chapterTitle: String?
    let selectedText: String
    let thoughtText: String
    let createdAt: Int64
}

/// 阅读设置同步负载（LWW 合并结构，与后端 /api/auth/reader-settings 对齐）
struct ReaderSettingsPayload: Codable {
    var settings: [String: String]
    var updatedAt: [String: Int64]
}

/// 忽略具体内容、只看状态码的响应（如 { success: true } 这类）
struct OkEnvelope: Codable { let success: Bool?; let ok: Bool? }
