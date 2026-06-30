import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var resendMessage: String?
    @State private var resendIsError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 56))
                    .foregroundStyle(Constants.Colors.primary)

                Text("Potvrdi email adresu")
                    .font(.title2.bold())

                Text("Poslali smo link za verifikaciju na:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let email = authViewModel.verificationEmail {
                    Text(email)
                        .font(.headline)
                        .textSelection(.enabled)
                }

                Text("Otvori link u mailu, zatim dodirni „Proveri ponovo”. Proveri i spam folder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let resendMessage {
                    Text(resendMessage)
                        .font(.footnote)
                        .foregroundStyle(resendIsError ? .red : .green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await checkVerification() }
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Proveri ponovo")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Constants.Colors.primary)
                    .disabled(authViewModel.isLoading)

                    Button {
                        Task { await resendEmail() }
                    } label: {
                        Text("Pošalji ponovo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(authViewModel.isLoading)

                    Button("Odjavi se", role: .destructive) {
                        authViewModel.logout()
                    }
                    .font(.subheadline)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding()
        }
    }

    private func checkVerification() async {
        resendMessage = nil
        let verified = await authViewModel.refreshEmailVerificationStatus()
        if verified {
            resendMessage = "Email je potvrđen. Dobrodošao!"
            resendIsError = false
        } else if authViewModel.errorMessage == nil {
            resendMessage = "Email još nije potvrđen. Otvori link u mailu pa pokušaj ponovo."
            resendIsError = true
        }
    }

    private func resendEmail() async {
        resendMessage = nil
        if let error = await authViewModel.resendVerificationEmail() {
            resendMessage = error
            resendIsError = true
        } else {
            resendMessage = "Novi link za verifikaciju je poslat."
            resendIsError = false
        }
    }
}
