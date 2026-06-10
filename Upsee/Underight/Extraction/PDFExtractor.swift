import Foundation
import PDFKit

/// Pull raw text from a CIM PDF. Tabular extraction lives in v1.5 (see
/// `features/03-source-verification.md`); for v1 we extract per-page text and
/// concatenate. The LLM does the rest of the parsing.
enum PDFExtractor {
    struct ExtractedText: Equatable {
        var pages: [String]
        var combined: String
        var pageCount: Int
    }

    enum ExtractionError: Error, LocalizedError {
        case couldNotOpenPDF
        case emptyPDF

        var errorDescription: String? {
            switch self {
            case .couldNotOpenPDF: return "Couldn't open the PDF — make sure it isn't encrypted."
            case .emptyPDF: return "This PDF appears to have no extractable text. Scanned CIMs need OCR first."
            }
        }
    }

    static func extract(from url: URL) throws -> ExtractedText {
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.couldNotOpenPDF
        }
        let count = document.pageCount
        var pages: [String] = []
        pages.reserveCapacity(count)
        for index in 0..<count {
            guard let page = document.page(at: index) else { continue }
            pages.append(page.string ?? "")
        }
        let combined = pages.enumerated()
            .map { "[Page \($0.offset + 1)]\n\($0.element)" }
            .joined(separator: "\n\n")
        if combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ExtractionError.emptyPDF
        }
        return ExtractedText(pages: pages, combined: combined, pageCount: count)
    }
}
