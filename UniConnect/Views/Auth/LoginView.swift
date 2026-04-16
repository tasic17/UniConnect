import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""

    var isFormValid: Bool {
        Validators.isValidEmail(email) && Validators.isValidPassword(password)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("UniConnect")
                    .font(.largeTitle.bold())
                    .foregroundColor(Constants.Colors.primary)

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Lozinka", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await authViewModel.login(email: email, password: password) }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Prijavi se")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.primary)
                .disabled(!isFormValid || authViewModel.isLoading)

                NavigationLink("Nemas nalog? Registruj se", destination: RegisterView())
                    .font(.subheadline)

                Spacer()
            }
            .padding()
        }
    }
}

