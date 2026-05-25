//
//  PDFTextExtractor.swift
//  Syllabus Sync
//

import Foundation
import UIKit

/// Protocol for extracting raw text from PDF files with optional first page preview.
protocol PDFTextExtractor {
    /// Extracts raw text for the entire PDF. May delete the source file after extraction.
    /// - Parameters:
    ///   - url: Local file URL to the PDF.
    ///   - deleteAfterExtract: If true, removes the file after reading.
    /// - Returns: Combined raw text across all pages.
    func extract(from url: URL, deleteAfterExtract: Bool) async throws -> String

    /// Renders a preview image for the first page of the PDF (for quick testing/verification).
    /// - Parameter url: Local file URL to the PDF.
    /// - Returns: The rendered first page image, if available.
    func firstPagePreview(from url: URL, maxDimension: CGFloat) async -> UIImage?

    /// Extracts structured content from a PDF, including plain text and TSV-friendly rows.
    /// - Parameter url: Local file URL to the PDF.
    /// - Returns: Tuple containing joined plain text, TSV formatted rows, and page count.
    func extractStructured(from url: URL) async throws -> (plain: String, tsv: String, pages: Int)
}

enum PDFTextExtractorError: LocalizedError {
    case fileTooLarge(maxMB: Int)
    case tooManyPages(maxPages: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maxMB):
            return "The PDF is too large. Please choose a file under \(maxMB) MB."
        case .tooManyPages(let maxPages):
            return "The PDF has too many pages. Please choose a file with \(maxPages) pages or fewer."
        }
    }
}
