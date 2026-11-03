import SwiftUI

struct ArticleView: View {
    @Environment(AppStore.self) private var store
    let id: Int
    @State private var resource = Resource<Article>()
    @State private var related = Resource<[Article]>()
    @State private var original = false
    @AppStorage("life.reader.largeText") private var largeText = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ResourceContent(resource: resource, retry: { Task { await load() } }) { article in
                    Eyebrow(text: sourceName(article.source) + " / Red TV READ")
                    Text(original ? (article.title.isEmpty ? "BBC 英文原文" : article.title) : article.displayTitle)
                        .font(.system(.largeTitle, weight: .bold)).lineSpacing(5).textSelection(.enabled)
                    Text("\(sourceName(article.source)) · \(LifeDate.display(article.publishedAt, time: true))").font(.caption).foregroundStyle(.secondary)
                    ReadingActions(item: article.libraryItem)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { languageButton; textSizeButton }
                        VStack(alignment: .leading, spacing: 10) { languageButton; textSizeButton }
                    }
                    let summary = original ? article.summary : article.displaySummary
                    if !summary.isEmpty {
                        Text(summary).font(.title3).foregroundStyle(.secondary).lineSpacing(6).textSelection(.enabled)
                    }
                    if let imageURL = externalURL(article.imageUrl) { BBCArticleImage(url: imageURL).frame(height: 220) }
                    let text = original ? article.body : article.bodyZh.isEmpty ? article.body : article.bodyZh
                    if original {
                        Label("英文原文 · BBC", systemImage: "globe").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    } else if !article.bodyZh.isEmpty {
                        Notice(text: "以下为自动翻译，可点“查看英文原文”核对。")
                    } else if !article.body.isEmpty {
                        Notice(text: article.bodyTranslationError?.isEmpty == false ? "中文译文暂不可用，以下显示 BBC 英文原文。" : "中文译文尚未同步，以下先显示 BBC 英文原文。")
                    }
                    if text.isEmpty {
                        if original {
                            Notice(text: "英文正文暂未同步，可前往 BBC 阅读完整原文。")
                            SourceLink(raw: article.sourceUrl, title: "在 BBC 打开英文原文")
                        } else {
                            Notice(text: article.bodyFetchError?.isEmpty == false ? "正文暂不可读，当前展示已同步摘要。" : "完整正文尚未同步，当前展示摘要。")
                        }
                    } else {
                        ForEach(Array(text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph).font(largeText ? .title3 : .body).lineSpacing(largeText ? 12 : 9).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Divider()
                    if !original || !text.isEmpty { SourceLink(raw: article.sourceUrl, title: "在 BBC 查看原始报道") }
                    Text("完整上下文与最终版本请以 BBC 原文为准。").font(.caption).foregroundStyle(.secondary)
                    if let articles = related.value?.filter({ $0.source.lowercased() == "bbc" }), !articles.isEmpty {
                        SectionHeading(title: "继续阅读")
                        ForEach(articles) { article in NavigationLink(value: Route.article(article.id)) { ArticleCard(article: article) }.buttonStyle(.plain) }
                    }
                }
            }.padding(22).lifePage()
        }.background(LifeTheme.paper).navigationTitle("阅读").navigationBarTitleDisplayMode(.inline).lifeDetailNavigation()
            .task(id: id) {
                await load()
                guard let article = resource.value else { return }
                await store.recordRead(article)
                await related.load { try await store.api.get("articles/\(id)/related") }
                for _ in 0..<5 {
                    guard let article = resource.value, !article.body.isEmpty, article.bodyZh.isEmpty,
                          article.bodyTranslationError?.isEmpty != false else { break }
                    do { try await Task.sleep(for: .seconds(5)); try Task.checkCancellation() } catch { return }
                    await load()
                    if resource.error != nil { break }
                }
            }.refreshable { await load() }
    }
    private var languageButton: some View {
        Button { original.toggle() } label: {
            Label(original ? "显示中文" : "查看英文原文", systemImage: original ? "character.bubble" : "globe")
        }.font(.subheadline.weight(.semibold)).buttonStyle(.borderedProminent)
            .accessibilityIdentifier("reader-language-toggle")
            .accessibilityValue(original ? "英文原文" : "中文优先")
    }
    private var textSizeButton: some View {
        Toggle("大字号", isOn: $largeText).toggleStyle(.button)
            .font(.subheadline).buttonStyle(.bordered).accessibilityIdentifier("reader-large-text")
    }
    private func load() async {
        await resource.load(key: "article-\(id)") {
            let article: Article = try await store.api.get("articles/\(id)")
            guard article.source.lowercased() == "bbc" else { throw APIError.http(0, "这篇报道来自旧版内容栏目，可在原网站查看。") }
            return article
        }
    }
}
