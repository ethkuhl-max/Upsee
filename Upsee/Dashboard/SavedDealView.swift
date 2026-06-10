import SwiftUI
import SwiftData

/// Reopens a previously analyzed deal from the dashboard: shows the saved underwriting
/// report (if any), lets the user move it through the pipeline, or delete it.
struct SavedDealView: View {
    @Bindable var deal: DealEntity
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var mode: Mode = .report

    private enum Mode: String, CaseIterable {
        case report, diligence
        var label: String { self == .report ? "Report" : "Diligence" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch mode {
                    case .report:
                        if let analysis = deal.savedAnalysis {
                            AnalysisDocumentView(analysis: analysis)
                        } else {
                            unanalyzedPlaceholder
                        }
                    case .diligence:
                        DealDiligenceView(deal: deal)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .principal) {
                    Picker("Status", selection: statusBinding) {
                        ForEach(DealStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        modelContext.delete(deal)
                        try? modelContext.save()
                        onClose()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var statusBinding: Binding<DealStatus> {
        Binding(
            get: { deal.status },
            set: {
                deal.status = $0
                deal.updatedAt = Date()
                try? modelContext.save()
            }
        )
    }

    private var unanalyzedPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(deal.businessName).font(.title2.weight(.semibold))
            Text("This deal hasn't been analyzed yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                MetricView(label: "Asking", value: currency(deal.askingPrice))
                MetricView(label: "SDE", value: currency(deal.reportedSDE))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }
}
