import SwiftUI
import SwiftData

struct IPSPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var documents: [IPSDocument]
    @Query(sort: \TargetAllocation.targetPercent, order: .reverse) private var targets: [TargetAllocation]
    @Query private var balanceSheet: [BalanceSheetItem]

    @State private var addingTarget: AssetClass?

    private var ips: IPSDocument? { documents.first }

    private var rebalance: RebalanceSummary {
        PortfolioRebalanceEngine.summarize(targets: targets, balanceSheetItems: balanceSheet)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            ipsCard
            targetsBlock
            if !targets.isEmpty {
                rebalanceBlock
            }
        }
        .onAppear { ensureIPSExists() }
        .sheet(item: $addingTarget) { ac in
            EditAllocationSheet(assetClass: ac).frame(minWidth: 460, minHeight: 280)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Investment Policy Statement").font(.title3.weight(.semibold))
            Text("The IPS is what real advisors put in writing: target allocation, risk tolerance, time horizon, rebalancing rules. Rereading it quarterly prevents emotional drift.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var ipsCard: some View {
        if let ips {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    riskToleranceField(ips)
                    horizonField(ips)
                    Spacer()
                    if let last = ips.lastReviewedAt {
                        Text("Last reviewed \(relative(last))").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    Button("Reviewed today") {
                        ips.lastReviewedAt = Date()
                        try? modelContext.save()
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
                IPSBodyEditor(ips: ips)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
        }
    }

    private func riskToleranceField(_ ips: IPSDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RISK TOLERANCE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Picker("Risk", selection: Binding(
                get: { ips.riskTolerance },
                set: { ips.riskTolerance = $0; try? modelContext.save() }
            )) {
                ForEach(RiskTolerance.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu).labelsHidden()
            .frame(maxWidth: 160)
        }
    }

    private func horizonField(_ ips: IPSDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HORIZON").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Stepper(value: Binding(
                get: { ips.timeHorizonYears },
                set: { ips.timeHorizonYears = $0; try? modelContext.save() }
            ), in: 1...60) {
                Text("\(ips.timeHorizonYears) yrs").monospacedDigit()
            }
        }
    }

    private var targetsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TARGET ALLOCATION").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                if !rebalance.targetSumValid && !targets.isEmpty {
                    Text("(does not sum to 100%)").font(.caption2).foregroundStyle(.orange)
                }
                Spacer()
                Menu {
                    ForEach(AssetClass.allCases, id: \.self) { ac in
                        if !targets.contains(where: { $0.assetClass == ac }) {
                            Button(ac.displayName) { addingTarget = ac }
                        }
                    }
                } label: {
                    Label("Add asset class", systemImage: "plus.circle").font(.caption)
                }
                .menuStyle(.borderlessButton)
            }
            if targets.isEmpty {
                EmptyHint(text: "Define target allocation by asset class. CFP starting point: \(suggestionFromIPS())")
            } else {
                ForEach(targets) { t in
                    TargetRow(target: t, onTap: { addingTarget = t.assetClass }, onDelete: {
                        modelContext.delete(t)
                        try? modelContext.save()
                    })
                }
            }
        }
    }

    private var rebalanceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CURRENT VS TARGET").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                if rebalance.needsRebalance {
                    Pill(text: "Rebalance suggested", tint: .orange)
                } else {
                    Pill(text: "Within bands", tint: .green)
                }
            }
            ForEach(rebalance.lines) { line in
                AllocationRow(line: line)
            }
        }
    }

    private func suggestionFromIPS() -> String {
        guard let ips else { return "" }
        let mix = ips.riskTolerance.suggestedStockBondMix
        return "\(Int(mix.stocks * 100))% stocks / \(Int(mix.bonds * 100))% bonds"
    }

    private func ensureIPSExists() {
        if documents.isEmpty {
            modelContext.insert(IPSDocument())
            try? modelContext.save()
        }
    }
}

private struct IPSBodyEditor: View {
    @Bindable var ips: IPSDocument
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("POLICY STATEMENT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: $ips.body)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.25)))
            HStack {
                Spacer()
                Button("Save") {
                    ips.updatedAt = Date()
                    try? modelContext.save()
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}

private struct TargetRow: View {
    let target: TargetAllocation
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: target.assetClass.systemImage).foregroundStyle(target.assetClass.tint).frame(width: 22)
            Text(target.assetClass.displayName).font(.callout.weight(.medium))
            Spacer()
            Text(String(format: "%.0f%%", target.targetPercent * 100))
                .font(.callout.monospacedDigit())
            Text("± \(Int(target.driftThreshold * 100))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(action: onTap) {
                Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(target.assetClass.tint.opacity(0.05)))
    }
}

private struct AllocationRow: View {
    let line: AllocationLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: line.assetClass.systemImage).foregroundStyle(line.assetClass.tint)
                Text(line.assetClass.displayName).font(.callout.weight(.medium))
                Spacer()
                Text(String(format: "%.1f%%", line.currentPercent * 100))
                    .font(.callout.monospacedDigit())
                Text("/").foregroundStyle(.tertiary)
                Text(String(format: "%.0f%%", line.targetPercent * 100))
                    .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.secondary.opacity(0.10))
                    Rectangle().fill(line.assetClass.tint.opacity(0.7))
                        .frame(width: geo.size.width * min(line.currentPercent, 1.0))
                    Rectangle().fill(Color.primary.opacity(0.4))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * line.targetPercent)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            HStack {
                Text(line.suggestedAction)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(line.needsRebalance ? Color.orange : Color.secondary)
                Spacer()
                Text("Drift: \(String(format: "%+.1f%%", line.drift * 100))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(abs(line.drift) > 0.05 ? Color.orange : .secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(line.assetClass.tint.opacity(0.05)))
    }
}

struct EditAllocationSheet: View {
    let assetClass: AssetClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var targets: [TargetAllocation]

    @State private var percent: Double = 0
    @State private var drift: Double = 0.05

    private var existing: TargetAllocation? {
        targets.first { $0.assetClass == assetClass }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: assetClass.systemImage).foregroundStyle(assetClass.tint)
                Text(assetClass.displayName).font(.title3.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Target percent: \(Int(percent * 100))%").font(.callout.weight(.medium))
                Slider(value: $percent, in: 0...1, step: 0.01)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Drift threshold: ±\(Int(drift * 100))%").font(.callout.weight(.medium))
                Slider(value: $drift, in: 0.01...0.20, step: 0.01)
            }
            Spacer()
            HStack {
                if existing != nil {
                    Button("Remove", role: .destructive) {
                        if let existing { modelContext.delete(existing); try? modelContext.save() }
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    if let existing {
                        existing.targetPercent = percent
                        existing.driftThreshold = drift
                        existing.updatedAt = Date()
                    } else {
                        modelContext.insert(TargetAllocation(assetClass: assetClass, targetPercent: percent, driftThreshold: drift))
                    }
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .onAppear {
            if let existing {
                percent = existing.targetPercent
                drift = existing.driftThreshold
            }
        }
    }
}
