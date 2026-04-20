import Foundation
import PDFKit

/// Extracts metadata from PDF files using native PDFKit.
enum PdfParser {

    struct PdfMetadata {
        let title: String?
        let author: String?
        let subject: String?
        let pageCount: Int
    }

    static func extractMetadata(from url: URL) -> PdfMetadata {
        guard let doc = PDFDocument(url: url) else {
            return PdfMetadata(
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                subject: nil,
                pageCount: 0
            )
        }

        let attrs = doc.documentAttributes ?? [:]
        let title = attrs[PDFDocumentAttribute.titleAttribute] as? String
        let author = attrs[PDFDocumentAttribute.authorAttribute] as? String
        let subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String

        return PdfMetadata(
            title: title,
            author: author,
            subject: subject,
            pageCount: doc.pageCount
        )
    }

    static func getChapters(from url: URL) -> [ChapterInfo] {
        guard let doc = PDFDocument(url: url) else { return [] }
        // Each page is a "chapter" for progress tracking
        return (0..<doc.pageCount).map { i in
            ChapterInfo(index: i, title: "Page \(i + 1)")
        }
    }
}
