import SwiftUI

struct PatientsView: View {
    @StateObject private var viewModel = PatientsViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchTerm)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List(viewModel.filteredPatients) { patient in
                        NavigationLink(destination: PatientDetailView(patient: patient)) {
                            PatientListItem(patient: patient)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Patients")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.load() }
        }
    }
}

struct PatientListItem: View {
    let patient: Patient

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(patient.initials)
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(patient.full_name)
                    .font(.headline)
                if let phone = patient.phone {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let gender = patient.gender {
                Text(gender == "M" ? "Homme" : "Femme")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PatientDetailView: View {
    let patient: Patient

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text(patient.initials)
                                .foregroundColor(.white)
                                .font(.title3)
                                .fontWeight(.bold)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(patient.full_name)
                            .font(.title2)
                            .fontWeight(.bold)
                        if let gender = patient.gender, let dob = patient.date_of_birth {
                            Text("\(gender == "M" ? "Homme" : "Femme") · \(dob)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    if let phone = patient.phone {
                        InfoRow(icon: "phone", label: "Téléphone", value: phone)
                    }
                    if let email = patient.email {
                        InfoRow(icon: "envelope", label: "Email", value: email)
                    }
                    if let address = patient.address {
                        InfoRow(icon: "location", label: "Adresse", value: address)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if let history = patient.medical_history, !history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Antécédents médicaux")
                            .font(.headline)
                        Text(history)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                if let allergies = patient.allergies, !allergies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("Allergies")
                                .font(.headline)
                        }
                        Text(allergies)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Détail patient")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
    }
}

@MainActor
class PatientsViewModel: ObservableObject {
    @Published var patients: [Patient] = []
    @Published var searchTerm = ""
    @Published var isLoading = false

    private let apiService = APIService.shared

    var filteredPatients: [Patient] {
        guard !searchTerm.isEmpty else { return patients }
        return patients.filter {
            $0.full_name.lowercased().contains(searchTerm.lowercased()) ||
            ($0.phone?.contains(searchTerm) ?? false)
        }
    }

    func load() { Task { await fetchPatients() } }
    func refresh() { Task { await fetchPatients() } }

    private func fetchPatients() async {
        isLoading = true
        do { patients = try await apiService.getPatients() } catch { }
        isLoading = false
    }
}

#Preview {
    PatientsView()
}
