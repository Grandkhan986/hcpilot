import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    @State private var email = "doctor@hcpilot.com"
    @State private var password = "password123"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .center, spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("HCPilot")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Système pour professionnels\nde santé à domicile")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                SecureField("Mot de passe", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            Button {
                print("[HCPilot] Button tapped!")
                Task {
                    await viewModel.login(email: email, password: password)
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Connexion")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)

            Spacer()

            Text("Compte de démo pré-rempli")
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
