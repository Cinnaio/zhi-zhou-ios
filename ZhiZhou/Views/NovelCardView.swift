import SwiftUI

/// 小说卡片（发现页列表项）：封面 + 标题/作者/简介/分类，暖调奶油玻璃卡片。
struct NovelCardView: View {
    let novel: Novel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover
            VStack(alignment: .leading, spacing: 6) {
                Text(novel.title)
                    .font(serifFont(17, .semibold))
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
                            .modifier(ThemeTagModifier())
                    }
                    Spacer()
                    Text("\(novel.chapterCount) 章")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
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

/// 分类/属性标签贴纸：奶白胶囊 + 暖色描边 + 轻阴影
struct ThemeTagModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .foregroundStyle(AppTheme.primaryDeep)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.75), in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.border, lineWidth: 0.75))
    }
}
