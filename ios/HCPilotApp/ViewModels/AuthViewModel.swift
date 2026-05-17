import Foundation
import Alamofire

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Veuillez remplir tous les champs."
            return
        }

        print("[HCPilot] Login attempt: \(email)")
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.login(email: email, password: password)
            print("[HCPilot] Login success: \(response.user.full_name)")
            self.user = response.user
            self.isAuthenticated = true
            self.errorMessage = nil
        } catch {
            print("[HCPilot] Login error: \(error)")
            self.errorMessage = "Erreur: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() {
        apiService.clearToken()
        isAuthenticated = false
        user = nil
    }
}
