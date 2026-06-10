import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onDrop: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isTargeted)

            VStack(spacing: 6) {
                Text("Drop a CIM here")
                    .font(.title2.weight(.medium))
                Text("Underight will read the seller's deal, run the math, and argue with their add-backs.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button("Open a PDF…") {
                pickPDF()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            Text("v0.1 — bring your own API key (⌘,)")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: isTargeted ? [] : [8, 6])
                )
                .padding(24)
        )
        .onDrop(of: [.pdf, .fileURL], isTargeted: $isTargeted) { providers in
            handleProviders(providers)
        }
    }

    private func handleProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url, url.pathExtension.lowercased() == "pdf" {
                DispatchQueue.main.async { onDrop(url) }
            }
        }
        return true
    }

    private func pickPDF() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.pdf]
        panel.title = "Choose a CIM PDF"
        if panel.runModal() == .OK, let url = panel.url {
            onDrop(url)
        }
    }
}

#Preview {
    DropZoneView(onDrop: { _ in })
        .frame(width: 920, height: 640)
}
