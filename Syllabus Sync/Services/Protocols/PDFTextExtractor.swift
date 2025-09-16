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
}
