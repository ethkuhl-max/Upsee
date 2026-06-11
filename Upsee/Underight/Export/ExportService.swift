import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// File export/import helpers: PDF rendering of an analysis, and save/open panels.
enum ExportService {
    static let underightType = UTType(filenameExtension: "underight") ?? .json
    static let markdownType = UTType(filenameExtension: "md") ?? .plainText

    @MainActor
    static func pdfData(for analysis: Analysis) -> Data? {
        pdfData(markdown: AnalysisMarkdown.render(analysis))
    }

    /// Renders any Markdown document to a single tall PDF page.
    @MainActor
    static func pdfData(markdown: String) -> Data? {
        let view = AnalysisPrintView(markdown: markdown)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 612, height: nil)

        var output: Data?
        renderer.render { size, renderInContext in
            let pdf = NSMutableData()
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdf as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            renderInContext(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            output = pdf as Data
        }
        return output
    }

    @discardableResult
    static func save(_ data: Data, suggestedName: String, type: UTType) -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return (try? data.write(to: url)) != nil
    }

    static func openData(types: [UTType]) -> Data? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Filesystem-safe filename stem from a display name.
    static func safeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        let cleaned = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let stem = String(cleaned).trimmingCharacters(in: .whitespaces)
        return stem.isEmpty ? "Untitled" : stem
    }
}

/// Static, print-friendly rendering of an analysis Markdown document (black on white).
struct AnalysisPrintView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(markdown.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                renderLine(line)
            }
        }
        .padding(40)
        .frame(width: 612, alignment: .leading)
        .background(Color.white)
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        if line == "---" {
            Divider()
        } else if line.hasPrefix("# ") {
            Text(inline(String(line.dropFirst(2)))).font(.title.weight(.bold)).foregroundStyle(.black)
        } else if line.hasPrefix("## ") {
            Text(inline(String(line.dropFirst(3)))).font(.title3.weight(.semibold)).foregroundStyle(.black).padding(.top, 8)
        } else if line.hasPrefix("### ") {
            Text(inline(String(line.dropFirst(4)))).font(.headline).foregroundStyle(.black).padding(.top, 4)
        } else if line.hasPrefix("> ") {
            Text(inline(String(line.dropFirst(2)))).font(.system(.title3, design: .serif).italic()).foregroundStyle(.black)
        } else if line.isEmpty {
            Color.clear.frame(height: 3)
        } else {
            Text(inline(line)).font(.body).foregroundStyle(.black)
        }
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }
}
