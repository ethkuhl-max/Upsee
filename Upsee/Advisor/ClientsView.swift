import SwiftUI
import SwiftData

/// The advisor's book of business: a client roster with AUM/fee/review rollups.
struct ClientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var addingClient = false
    @State private var search = ""

    private var book: BookSummary {
        BookOfBusinessEngine.summarize(clients.map {
            ClientBookInput(name: $0.name, aum: $0.aum, feePercent: $0.feePercent, status: $0.status, nextReviewDate: $0.nextReviewDate)
        }, asOf: Date())
    }

    private var filtered: [Client] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return clients }
        return clients.filter { $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                bookHeader
                if !book.upcomingReviews.isEmpty { reviewsCard }
                rosterSection
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
        }
        .navigationTitle("Clients")
        .searchable(text: $search, prompt: "Search clients")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addingClient = true } label: { Label("Add Client", systemImage: "person.badge.plus") }
            }
        }
        .sheet(isPresented: $addingClient) {
            AddClientSheet().frame(minWidth: 520, minHeight: 440)
        }
        .navigationDestination(for: Client.self) { client in
            ClientDetailView(client: client)
        }
    }

    private var bookHeader: some View {
        HStack(spacing: 14) {
            metric("AUM", currency(book.totalAUM), tint: .blue)
            metric("Annual revenue", currency(book.annualRevenue), tint: .green)
            metric("Avg fee", String(format: "%.2f%%", book.weightedAverageFee * 100))
            metric("Active", "\(book.activeCount)")
            metric("Prospects", "\(book.prospectCount)")
        }
    }

    private var reviewsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reviews due").font(.headline)
            ForEach(Array(book.upcomingReviews.enumerated()), id: \.offset) { _, review in
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(review.isOverdue ? .red : .orange)
                    Text(review.name).font(.callout)
                    Spacer()
                    Text(review.isOverdue ? "Overdue · \(dateString(review.date))" : dateString(review.date))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(review.isOverdue ? .red : .secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
    }

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Roster").font(.title3.weight(.semibold))
            if filtered.isEmpty {
                Text("No clients yet. Add your first client to get started.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { client in
                    NavigationLink(value: client) {
                        clientRow(client)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(client)
                            try? modelContext.save()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
    }

    private func clientRow(_ client: Client) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(client.status.tint.opacity(0.18)).frame(width: 40, height: 40)
                Text(initials(client.name)).font(.callout.weight(.semibold)).foregroundStyle(client.status.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name).font(.callout.weight(.medium))
                if !client.email.isEmpty {
                    Text(client.email).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Pill(text: client.status.displayName, tint: client.status.tint)
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency(client.aum)).font(.callout.monospacedDigit())
                Text(String(format: "%.2f%% fee", client.feePercent * 100)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(width: 110, alignment: .trailing)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
    }

    private func metric(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }
}

struct AddClientSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var status: ClientStatus = .prospect
    @State private var aum = ""
    @State private var feePercent = "1.0"
    @State private var cadence = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add client").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 14) {
                field("Name") { TextField("Jane & John Doe", text: $name).textFieldStyle(.roundedBorder) }
                field("Email") { TextField("optional", text: $email).textFieldStyle(.roundedBorder) }
                field("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ClientStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented)
                }
                field("AUM") { TextField("0", text: $aum).textFieldStyle(.roundedBorder).monospacedDigit() }
                field("Advisory fee (%)") { TextField("1.0", text: $feePercent).textFieldStyle(.roundedBorder).monospacedDigit() }
                field("Review cadence") {
                    Picker("Cadence", selection: $cadence) {
                        ForEach([3, 6, 12], id: \.self) { Text("\($0) mo").tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 220)
                }
            }
            Spacer()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let client = Client(name: name, email: email, status: status,
                                        aum: parseDecimal(aum), feePercent: (Double(feePercent) ?? 1) / 100.0,
                                        reviewCadenceMonths: cadence)
                    modelContext.insert(client)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent).disabled(name.isEmpty).keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func parseDecimal(_ s: String) -> Decimal {
        Decimal(string: s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
    }
}
