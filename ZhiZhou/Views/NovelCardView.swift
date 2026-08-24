import SwiftUI

/// 小说卡片（发现页列表项）：封面 + 标题/作者/简介/分类，Liquid Glass 玻璃卡片。
struct NovelCardView: View {
    let novel: Novel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover
            VStack(alignment: .leading, spacing: 6) {
                Text(novel.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(novel.author)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                if !novel.description.isEmpty {
                    Text(novel.description)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    ForEach(novel.categories.prefix(3), id: \.self) { category in
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.primaryLight, in: Capsule())
                            .foregroundStyle(AppTheme.primaryDeep)
                    }
                    Spacer()
                    Text("\(novel.chapterCount) 章")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }

    private var cover: some View {
        AsyncImage(url: APIClient.shared.coverURL(novelId: novel.id, updatedAt: novel.updatedAt)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    AppTheme.primaryLight
                    Image(systemName: "book.closed")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .frame(width: 76, height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
}
