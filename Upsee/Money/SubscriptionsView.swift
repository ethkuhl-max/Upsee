import SwiftUI

struct SubscriptionsView: View {
    let transactions: [Transaction]

    private var subs: [DetectedSubscription] {
        SubscriptionEngine.detect(transactions: transactions)
    }

    private var monthlyBurn: Decimal {
        SubscriptionEngine.monthlyBurn(subs)
    }

    private var zombies: [DetectedSubscription] {
        SubscriptionEngine.zombieCandidates(subs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if subs.isEmpty {
                EmptyHint(text: "No recurring charges detected yet. Import a few months of transactions and Upsee will find your subscriptions automatically.")
            } else {
                if !zombies.isEmpty {
                    zombieSection
                }
                Text("ACTIVE SUBSCRIPTIONS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(subs.filter { !$0.likelyCancelled }) { sub in
                    SubRow(sub: sub)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            stat("Detected", "\(subs.count)")
            stat("Monthly burn", currency(monthlyBurn), tint: .orange)
            stat("Annualized", currency(monthlyBurn * 12), tint: .red)
            stat("Zombies", "\(zombies.count)", tint: zombies.isEmpty ? .secondary : .red)
            Spacer()
        }
    }

    private var zombieSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text("Cancel candidates")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
            Text("Recurring charges that haven't landed in a while or look orphaned. Could be \(currency(SubscriptionEngine.monthlyBurn(zombies)))/mo recovered.")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(zombies) { sub in
                SubRow(sub: sub)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.2)))
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }
}

private struct SubRow: View {
    let sub: DetectedSubscription

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 30, height: 30)
                Image(systemName: "repeat.circle").foregroundStyle(.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(sub.merchant.capitalized).font(.callout.weight(.medium))
                    if sub.likelyCancelled {
                        Pill(text: "Stale \(sub.daysSinceLast)d", tint: .red)
                    } else if sub.isMaterial {
                        Pill(text: "Material", tint: .orange)
                    }
                }
                Text("\(sub.occurrences) charges · \(sub.cadence.displayName)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currency(sub.monthlyEquivalent))/mo").font(.callout.monospacedDigit())
                Text(currency(sub.annualSpend) + "/yr")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }
}
