import Foundation
@testable import ReadingList
import Testing

@Suite("ReaderArticle")
struct ReaderArticleTests {
    @Test func decodesReadabilityJSON() throws {
        let json = """
        {"title":"Hello","byline":"Jane Doe","siteName":"Example","content":"<p>Body</p>",\
        "textLength":420,"lang":"en","dir":null}
        """
        let article = try #require(ReaderArticle(json: json))

        #expect(article.title == "Hello")
        #expect(article.byline == "Jane Doe")
        #expect(article.content == "<p>Body</p>")
        #expect(article.textLength == 420)
        #expect(article.dir == nil)
        #expect(article.isReadable)
    }

    @Test func rejectsMalformedJSON() {
        #expect(ReaderArticle(json: "not json") == nil)
        #expect(ReaderArticle(json: #"{"title":"No content"}"#) == nil)
    }

    @Test func shortExtractionsAreNotReadable() {
        #expect(!ReaderArticle(content: "<p>Hi</p>", textLength: 40).isReadable)
        #expect(!ReaderArticle(content: "<p>Hi</p>").isReadable)
        #expect(ReaderArticle(content: "<p>Hi</p>", textLength: ReaderArticle.minimumTextLength).isReadable)
    }

    @Test func metadataLineJoinsSiteAndBylineWithoutDuplicates() {
        #expect(ReaderArticle(byline: "Jane", siteName: "Example", content: "").metadataLine == "Example · Jane")
        #expect(ReaderArticle(byline: "example", siteName: "Example", content: "").metadataLine == "Example")
        #expect(ReaderArticle(byline: "  ", content: "").metadataLine == nil)
    }

    @Test func htmlEscapesMetadataButKeepsContentMarkup() {
        let article = ReaderArticle(
            title: "<script>alert(1)</script> & more",
            byline: "\"Quoted\"",
            content: "<p><em>Body</em></p>",
            lang: "en\" onload=\"x"
        )
        let html = article.html()

        #expect(html.contains("&lt;script&gt;alert(1)&lt;/script&gt; &amp; more"))
        #expect(!html.contains("<script>"))
        #expect(html.contains("&quot;Quoted&quot;"))
        #expect(html.contains("<p><em>Body</em></p>"))
        #expect(html.contains("lang=\"en&quot; onload=&quot;x\""))
        #expect(html.contains("script-src 'none'"))
    }
}
