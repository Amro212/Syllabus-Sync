//
//  PDFKitExtractor.swift
//  Syllabus Sync
//

import Foundation
import PDFKit
import Vision
import UIKit

/// Vision-only implementation of `PDFTextExtractor`.
///
/// The extractor rasterizes each page, runs Vision OCR, and applies noise
/// reduction (confidence filtering, Unicode cleanup, duplicate/header removal)
/// before returning plain text or TSV representations.
final class PDFKitExtractor: PDFTextExtractor {
    private let minimumConfidence: VNConfidence = 0.6

    func extract(from url: URL, deleteAfterExtract: Bool = false) async throws -> String {
        let result = try await performOCR(from: url)

        if deleteAfterExtract {
            try? FileManager.default.removeItem(at: url)
        }

        return result.plain
    }

    func firstPagePreview(from url: URL, maxDimension: CGFloat = 512) async -> UIImage? {
        let needsSecurity = url.startAccessingSecurityScopedResource()
        defer { if needsSecurity { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else {
            return nil
        }
        // Use PDFKit thumbnail for speed; sufficient for a quick preview.
        let size = CGSize(width: maxDimension, height: maxDimension)
        return page.thumbnail(of: size, for: .mediaBox)
    }

    // MARK: - Helpers

    func extractStructured(from url: URL) async throws -> (plain: String, tsv: String, pages: Int) {
        try await performOCR(from: url)
    }

    // MARK: - OCR pipeline

    private struct RecognizedLine {
        let text: String
        let rect: CGRect
        let confidence: VNConfidence
    }

    private struct RecognizedPage {
        let index: Int
        let size: CGSize
        let lines: [RecognizedLine]
    }

    private func performOCR(from url: URL) async throws -> (plain: String, tsv: String, pages: Int) {
        let needsSecurity = url.startAccessingSecurityScopedResource()
        defer { if needsSecurity { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else {
            return (plain: "", tsv: "", pages: 0)
        }

        var pages: [RecognizedPage] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                pages.append(RecognizedPage(index: index, size: .zero, lines: []))
                continue
            }

            let raster = renderPageToImageForOCR(page: page)
            let pageSize: CGSize
            if let cgImage = raster {
                pageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
                let observations = try await recognizeTextObservations(in: cgImage)
                let lines = buildLines(from: observations, imageSize: pageSize)
                pages.append(RecognizedPage(index: index, size: pageSize, lines: lines))
            } else {
                // Use media box size as a fallback for heuristics
                pageSize = page.bounds(for: .mediaBox).size
                pages.append(RecognizedPage(index: index, size: pageSize, lines: []))
            }
        }

        let plain = buildPlainText(from: pages)
        let tsv = buildTSV(from: pages)

        return (plain: plain, tsv: tsv, pages: document.pageCount)
    }

    private func recognizeTextObservations(in image: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, err in
                if let err = err {
                    continuation.resume(throwing: err)
                    return
                }
                let results = (req.results as? [VNRecognizedTextObservation]) ?? []
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-CA"]
            if #available(iOS 16.0, *) { request.revision = VNRecognizeTextRequestRevision3 }
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func buildLines(from observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [RecognizedLine] {
        observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            guard candidate.confidence >= minimumConfidence else { return nil }

            let sanitized = sanitizeCandidateText(candidate.string)
            guard !sanitized.isEmpty else { return nil }

            let rect = convertToImageRect(observation.boundingBox, imageSize: imageSize)

            return RecognizedLine(text: sanitized, rect: rect, confidence: candidate.confidence)
        }
    }

    private func buildPlainText(from pages: [RecognizedPage]) -> String {
        guard !pages.isEmpty else { return "" }

        var lineCounts: [String: Int] = [:]
        for page in pages {
            for line in page.lines {
                let key = canonicalKey(for: line.text)
                lineCounts[key, default: 0] += 1
            }
        }

        var previousKey: String?
        var resultBlocks: [String] = []

        for page in pages {
            guard !page.lines.isEmpty else { continue }

            let sorted = page.lines.sorted { lhs, rhs in
                if abs(lhs.rect.minY - rhs.rect.minY) < 4 {
                    return lhs.rect.minX < rhs.rect.minX
                }
                return lhs.rect.minY < rhs.rect.minY
            }

            var pageLines: [String] = []
            var pageSeen = Set<String>()

            for line in sorted {
                let key = canonicalKey(for: line.text)
                if key.isEmpty { continue }
                if key == previousKey { continue }
                if pageSeen.contains(key) { continue }
                if shouldSkipLine(line, in: page, canonicalKey: key, counts: lineCounts) { continue }

                pageLines.append(line.text)
                pageSeen.insert(key)
                previousKey = key
            }

            if !pageLines.isEmpty {
                resultBlocks.append(pageLines.joined(separator: "\n"))
            }
        }

        guard !resultBlocks.isEmpty else { return "" }

        let joined = resultBlocks.joined(separator: "\n\n")
        let dehyphenated = joined.replacingOccurrences(of: "-\n", with: "")
        let collapsedWhitespace = dehyphenated.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildTSV(from pages: [RecognizedPage]) -> String {
        guard !pages.isEmpty else { return "" }

        var rows: [String] = []

        for page in pages {
            if page.lines.isEmpty {
                rows.append("")
                continue
            }

            let tolerance = max(6, page.size.height * 0.012)
            let sorted = page.lines.sorted { $0.rect.midY < $1.rect.midY }
            var grouped: [[RecognizedLine]] = []

            for line in sorted {
                if var current = grouped.last, let anchor = current.first, abs(line.rect.midY - anchor.rect.midY) <= tolerance {
                    current.append(line)
                    grouped[grouped.count - 1] = current
                } else {
                    grouped.append([line])
                }
            }

            for group in grouped {
                let ordered = group.sorted { $0.rect.minX < $1.rect.minX }
                let columns = ordered.map { $0.text }
                let row = columns.joined(separator: "\t")
                if !row.isEmpty {
                    rows.append(row)
                }
            }

            rows.append("")
        }

        while rows.last == "" { rows.removeLast() }

        return rows.joined(separator: "\n")
    }

    private func shouldSkipLine(_ line: RecognizedLine, in page: RecognizedPage, canonicalKey: String, counts: [String: Int]) -> Bool {
        let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        let occurrences = counts[canonicalKey, default: 0]
        if occurrences > 1 {
            let pageHeight = page.size.height > 0 ? page.size.height : 1
            let relativeY = line.rect.midY / pageHeight
            if relativeY < 0.12 || relativeY > 0.88 { return true }
        }

        if occurrences > 1,
           trimmed.range(of: #"page\s+\d+"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        return false
    }

    private func sanitizeCandidateText(_ text: String) -> String {
        let normalized = text.precomposedStringWithCanonicalMapping
        let filteredScalars = normalized.unicodeScalars.filter { scalar in
            let category = scalar.properties.generalCategory
            return category != Unicode.GeneralCategory.control && category != Unicode.GeneralCategory.format
        }
        var cleaned = String(String.UnicodeScalarView(filteredScalars))
        cleaned = cleaned.replacingOccurrences(of: "\u{00AD}", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    private func canonicalKey(for text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Computes a high-resolution raster of the page aimed at ~300 DPI for better OCR quality.
    private func renderPageToImageForOCR(page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        // PDF points are 72 DPI; target ~300 DPI for OCR clarity.
        let targetDPI: CGFloat = 300
        let scale = max(3.5, targetDPI / 72.0)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // render at logical points; we manage scale ourselves
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            // Fill white background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Flip the context vertically (UIKit top-left → PDF bottom-left)
            let cg = ctx.cgContext
            cg.saveGState()
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: scale, y: -scale) // scale to target DPI and flip Y
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()
        }
        return image.cgImage
    }

    private func convertToImageRect(_ boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        let x = boundingBox.origin.x * imageSize.width
        let yBottom = boundingBox.origin.y * imageSize.height
        let width = boundingBox.size.width * imageSize.width
        let height = boundingBox.size.height * imageSize.height
        let y = imageSize.height - yBottom - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

}
