import SwiftUI

struct AssetAllocationCard: View {
    let summary: AssetAllocationSummary

    var body: some View {
        if summary.slices.isEmpty {
            EmptyHint(text: "Add assets on your balance sheet (Dashboard → Personal) to see allocation.")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if !summary.concentrationFlags.isEmpty {
                    concentrationFlagBanner
                }
                ForEach(summary.slices) { slice in
                    SliceRow(slice: slice)
                }
                HStack {
                    Spacer()
                    Text("Total assets: \(currency(summary.totalAssets))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var concentrationFlagBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Concentration flagged")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("\(summary.concentrationFlags.map { $0.displayName }.joined(separator: ", ")) — over 40% of total assets each. Single failure mode → big hit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
    }
}

private struct SliceRow: View {
    let slice: AssetAllocationSlice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: slice.category.systemImage)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(slice.category.displayName)
                .font(.callout.weight(.medium))
                .frame(width: 140, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint)
                        .frame(width: max(4, geo.size.width * slice.percentage))
                }
            }
            .frame(height: 14)
            Text(String(format: "%.0f%%", slice.percentage * 100))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            Text(currency(slice.amount))
                .font(.callout.monospacedDigit())
                .frame(width: 110, alignment: .trailing)
        }
    }

    private var tint: Color {
        switch slice.category {
        case .cash: return .green
        case .investments: return .blue
        case .retirement: return .purple
        case .realEstate: return .orange
        case .vehicle: return .yellow
        case .otherAsset: return .gray
        default: return .secondary
        }
    }
}
