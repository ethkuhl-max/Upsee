import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The Underight deal-analysis flow, presented as a sheet from the Upsee dashboard.
/// State machine lives in `AnalysisCoordinator`. `onClose` returns the user to the
/// dashboard once they're done (or hit cancel from any phase).
struct DealAnalysisFlowView: View {
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = AnalysisCoordinator()

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()

            Group {
                switch coordinator.phase {
                case .idle:
                    DropZoneView { url in coordinator.acceptDroppedPDF(at: url) }
                case .extracting(let filename):
                    LoadingView(message: "Reading \(filename)…", subtitle: "Extracting deal terms on-device")
                case .reviewing(let deal):
                    DealCardView(
                        initial: deal,
                        onAnalyze: { coordinator.startAnalysis(of: $0) },
                        onCancel: { coordinator.reset() }
                    )
                case .analyzing(let deal):
                    LoadingView(
                        message: "Underwriting \(deal.businessName)…",
                        subtitle: "Arguing with the add-backs"
                    )
                case .complete(let analysis):
                    AnalysisDocumentView(
                        analysis: analysis,
                        onNew: { coordinator.reset() },
                        onSave: { save($0) }
                    )
                case .failed(let message):
                    FailureView(message: message, onRetry: { coordinator.reset() })
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    /// Upserts the analysis into the dashboard: updates an existing deal with the same
    /// id (re-analysis), otherwise inserts a new one. Pipeline status is preserved.
    private func save(_ analysis: Analysis) {
        let id = analysis.deal.id
        let descriptor = FetchDescriptor<DealEntity>(predicate: #Predicate { $0.dealID == id })
        let existing = try? modelContext.fetch(descriptor).first
        let entity = existing ?? DealEntity(businessName: analysis.deal.businessName)
        entity.apply(analysis)
        if existing == nil {
            modelContext.insert(entity)
        }
        try? modelContext.save()
    }
}

private struct LoadingView: View {
    let message: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(message).font(.title3.weight(.medium))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .padding(48)
    }
}

private struct FailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.orange)
            Text("Something didn't go right").font(.title3.weight(.medium))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Start over", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 12)
        }
        .padding(48)
    }
}
