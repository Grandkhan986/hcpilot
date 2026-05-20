import SwiftUI

struct InvoicesView: View {
    @StateObject private var viewModel = InvoicesViewModel()
    @State private var showNewInvoiceSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchTerm)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Picker("Filtre", selection: $viewModel.filter) {
                    Text("Tous").tag("all")
                    Text("Payées").tag("paid")
                    Text("Envoyées").tag("sent")
                    Text("En attente").tag("draft")
                    Text("En retard").tag("overdue")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List(viewModel.filteredInvoices) { invoice in
                        NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                            InvoiceListItem(invoice: invoice)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Factures")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewInvoiceSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewInvoiceSheet) {
                NewInvoiceView(onCreated: { viewModel.refresh() })
            }
            .onAppear { viewModel.load() }
        }
    }
}

struct InvoiceListItem: View {
    let invoice: Invoice

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(statusLetter)
                        .foregroundColor(.white)
                        .font(.caption2)
                        .fontWeight(.bold)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.invoice_number)
                    .font(.headline)

                if let items = invoice.items, let first = items.first {
                    Text(first.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(invoice.created_at, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f €", invoice.total))
                    .font(.headline)
                    .fontWeight(.semibold)

                InvoiceStatusBadge(status: invoice.status)
            }
        }
        .padding()
    }

    private var statusColor: Color {
        switch invoice.status {
        case .paid: return .green
        case .sent: return .blue
        case .overdue: return .red
        default: return .gray
        }
    }

    private var statusLetter: String {
        switch invoice.status {
        case .paid: return "P"
        case .sent: return "E"
        case .overdue: return "R"
        default: return "B"
        }
    }
}

struct InvoiceStatusBadge: View {
    let status: Invoice.InvoiceStatus

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor)
            .foregroundColor(fgColor)
            .cornerRadius(4)
    }

    private var label: String {
        switch status {
        case .paid: return "Payée"
        case .sent: return "Envoyée"
        case .overdue: return "En retard"
        default: return "Brouillon"
        }
    }

    private var bgColor: Color {
        switch status {
        case .paid: return Color.green.opacity(0.2)
        case .sent: return Color.blue.opacity(0.2)
        case .overdue: return Color.red.opacity(0.2)
        default: return Color.gray.opacity(0.2)
        }
    }

    private var fgColor: Color {
        switch status {
        case .paid: return .green
        case .sent: return .blue
        case .overdue: return .red
        default: return .gray
        }
    }
}

@MainActor
class InvoicesViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var searchTerm = ""
    @Published var filter = "all"
    @Published var isLoading = false
    @Published var errorMessage: String?

    let apiService = APIService.shared

    var filteredInvoices: [Invoice] {
        invoices.filter { invoice in
            let matchesSearch = searchTerm.isEmpty ||
                invoice.invoice_number.lowercased().contains(searchTerm.lowercased())
            let matchesFilter = filter == "all" || invoice.status.rawValue == filter
            return matchesSearch && matchesFilter
        }
    }

    func load() {
        Task { await fetchInvoices() }
    }

    func refresh() {
        Task { await fetchInvoices() }
    }

    private func fetchInvoices() async {
        isLoading = true
        do {
            invoices = try await apiService.getInvoices()
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct InvoiceDetailView: View {
    let invoice: Invoice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Facture")
                            .font(.headline)
                        Text(invoice.invoice_number)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    InvoiceStatusBadge(status: invoice.status)
                }

                // Items
                if let items = invoice.items {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Détails")
                            .font(.headline)
                        ForEach(items) { item in
                            HStack {
                                Text(item.description)
                                    .font(.subheadline)
                                Spacer()
                                Text("x\(item.quantity)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", item.price))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }

                // Total
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total à payer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f €", invoice.total))
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NewInvoiceView: View {
    @Environment(\.dismiss) var dismiss
    var onCreated: () -> Void
    @State private var description = ""
    @State private var quantity = 1
    @State private var price = 0.0

    let apiService = APIService.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Article")) {
                    TextField("Description", text: $description)
                    Stepper(value: $quantity, in: 1...100) {
                        Text("Quantité: \(quantity)")
                    }
                    TextField("Prix", value: $price, format: .currency(code: "EUR"))
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Nouvelle Facture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { createInvoice() }
                        .disabled(description.isEmpty)
                }
            }
        }
    }

    private func createInvoice() {
        let item = InvoiceItem(description: description, quantity: quantity, price: price)
        let invoice = Invoice(
            id: UUID().uuidString,
            client_id: "pat_001",
            client_name: nil,
            session_id: nil,
            invoice_number: "INV-NEW",
            status: .draft,
            subtotal: price * Double(quantity),
            tax: 0,
            discount: 0,
            total: price * Double(quantity),
            items: [item],
            due_date: Date(),
            paid_at: nil,
            stripe_payment_intent_id: nil,
            created_at: Date(),
            updated_at: nil
        )
        Task {
            do {
                _ = try await apiService.createInvoice(invoice: invoice)
                onCreated()
                dismiss()
            } catch {
                print("Erreur: \(error)")
            }
        }
    }
}

#Preview {
    InvoicesView()
}
