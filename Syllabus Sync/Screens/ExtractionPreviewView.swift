//
//  ExtractionPreviewView.swift
//  Syllabus Sync
//

import SwiftUI

struct ExtractionPreviewView: View {
    enum Tab: String, CaseIterable { case text = "Text", table = "Table (TSV)" }

    let image: UIImage?
    let text: String
    let tsv: String
    @State private var tab: Tab = .text

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(Layout.CornerRadius.md)
                        .padding([.horizontal, .top])
                }

                Picker("Preview", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                        switch tab {
                        case .text:
                            if text.isEmpty {
                                Text("No text extracted.")
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text(text)
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)
                                    .textSelection(.enabled)
                            }
                        case .table:
                            if tsv.isEmpty {
                                Text("No TSV detected.")
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text(tsv)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(AppColors.textPrimary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
