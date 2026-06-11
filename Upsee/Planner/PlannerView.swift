import SwiftUI

struct PlannerView: View {
    @State private var tab: PlannerTab = .goals

    enum PlannerTab: String, CaseIterable, Identifiable {
        case goals, insurance, ips, roth, estate, waterfall
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .goals: return "Goals"
            case .insurance: return "Insurance"
            case .ips: return "IPS"
            case .roth: return "Roth"
            case .estate: return "Estate"
            case .waterfall: return "Waterfall"
            }
        }

        var systemImage: String {
            switch self {
            case .goals: return "target"
            case .insurance: return "shield.lefthalf.filled"
            case .ips: return "doc.text.below.ecg"
            case .roth: return "arrow.left.arrow.right.circle"
            case .estate: return "signature"
            case .waterfall: return "chart.bar.xaxis"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Tab", selection: $tab) {
                    ForEach(PlannerTab.allCases) { t in
                        Label(t.displayName, systemImage: t.systemImage).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .goals: GoalsPlannerView()
                case .insurance: InsurancePlannerView()
                case .ips: IPSPlannerView()
                case .roth: RothPlannerView()
                case .estate: EstatePlannerView()
                case .waterfall: WaterfallPlannerView()
                }
            }
            .padding(24)
        }
        .navigationTitle("Planner")
    }
}
