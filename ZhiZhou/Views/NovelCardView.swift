import SwiftUI

/// 小说卡片（发现页列表项）：封面 + 标题/作者/简介/分类。
struct NovelCardView: View {
    let novel: Novel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover
            VStack(alignment: .leading, spacing: 6) {
                Text(novel.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(novel.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.border, lineWidth: 1)
        )
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
    }
}
