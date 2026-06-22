import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    let prefilledEmail: String

    @State private var email = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSendResetLink = false

    private var isFormValid: Bool {
        Validators.isValidEmail(email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Unesi email adresu naloga. Poslaćemo ti link za postavljanje nove lozinke.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Email") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .disabled(isSending || didSendResetLink)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }

                if didSendResetLink {
                    Section {
                        Label {
                            Text("Ako postoji nalog sa tim emailom, poslali smo link za reset lozinke. Proveri inbox i spam folder.")
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task { await sendResetLink() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSending {
                                ProgressView()
                            } else {
                                Text(didSendResetLink ? "Pošalji ponovo" : "Pošalji link")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isSending)
                }
            }
            .navigationTitle("Zaboravljena lozinka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zatvori") { dismiss() }
                }
            }
            .onAppear {
                email = prefilledEmail
            }
        }
    }

    private func sendResetLink() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        if let error = await authViewModel.resetPassword(email: email) {
            errorMessage = error
            didSendResetLink = false
        } else {
            didSendResetLink = true
        }
    }
}
