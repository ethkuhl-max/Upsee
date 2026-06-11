import SwiftUI

struct RepoHealthCard: View {
    let report: RepoHealthReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = report.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(error).font(.callout).foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 14) {
                    statBlock("Last commit", lastCommitLabel, tint: lastCommitTint)
                    statBlock("Branches", "\(report.branchCount)", tint: .blue)
                    statBlock("Uncommitted", "\(report.uncommittedFiles)", tint: report.uncommittedFiles > 0 ? .orange : .secondary)
                    if report.hasUpstream {
                        statBlock("Sync", syncLabel, tint: syncTint)
                    }
                }
                if let msg = report.lastCommitMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "text.quote").foregroundStyle(.secondary)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }

    private var lastCommitLabel: String {
        guard let days = report.daysSinceLastCommit else { return "—" }
        if days == 0 { return "Today" }
        if days == 1 { return "1d" }
        return "\(days)d"
    }

    private var lastCommitTint: Color {
        guard let days = report.daysSinceLastCommit else { return .secondary }
        switch days {
        case 0...3: return .green
        case 4...14: return .blue
        case 15...30: return .orange
        default: return .red
        }
    }

    private var syncLabel: String {
        if report.ahead == 0 && report.behind == 0 { return "Even" }
        return "+\(report.ahead) / -\(report.behind)"
    }

    private var syncTint: Color {
        if report.ahead == 0 && report.behind == 0 { return .green }
        if report.behind > 0 { return .orange }
        return .blue
    }

    private func statBlock(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
