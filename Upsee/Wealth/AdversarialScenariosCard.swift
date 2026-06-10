import SwiftUI

struct AdversarialScenariosCard: View {
    let apps: [AppEntity]
    let jobs: [JobEntity]
    let deals: [DealEntity]
    let personal: PersonalEntity?
    let retirement: [RetirementAccount]
    let netWorth: Decimal
    let liquidAssets: Decimal
    let concentrationFlags: [BalanceSheetCategory]

    @State private var generator = WealthAdversarialGenerator()
    @State private var isGenerating = false
    @State private var output: AdversarialWealthOutput?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let output {
                ForEach(Array(output.scenarios.enumerated()), id: \.offset) { _, scenario in
                    ScenarioCard(scenario: scenario)
                }
            } else if isGenerating {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Underight is finding the bear cases…").font(.callout).foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                EmptyHint(text: "Generate 3 honest bear-case scenarios specific to your portfolio. The version of your future you wouldn't write for yourself.")
            }
            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(errorMessage).font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                Task { await generate() }
            } label: {
                Label(isGenerating ? "Generating…" : (output == nil ? "Generate" : "Regenerate"), systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .disabled(isGenerating)
        }
    }

    @MainActor
    private func generate() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            output = try await generator.generate(
                apps: apps,
                jobs: jobs,
                deals: deals,
                personal: personal,
                retirement: retirement,
                netWorth: netWorth,
                liquidAssets: liquidAssets,
                concentrationFlags: concentrationFlags
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ScenarioCard: View {
    let scenario: AdversarialWealthScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(scenario.title)
                    .font(.callout.weight(.semibold))
            }
            row("Trigger", scenario.trigger, tint: .orange)
            row("Impact", scenario.impact, tint: .red)
            row("Mitigation", scenario.mitigation, tint: Color.accentColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.2)))
    }

    @ViewBuilder
    private func row(_ label: String, _ text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
        }
    }
}
