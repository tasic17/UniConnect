import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var year = 1
    @State private var department: AppUser.Department = .softversko

    var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Validators.isValidEmail(email) &&
        Validators.isValidPassword(password)
    }

    var body: some View {
        Form {
            Section("Osnovno") {
                TextField("Ime i prezime", text: $displayName)
                    .textInputAutocapitalization(.words)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                SecureField("Lozinka (min 6 karaktera)", text: $password)
            }

            Section("Studije") {
                Stepper("Godina: \(year)", value: $year, in: 1...6)
                Picker("Smer", selection: $department) {
                    ForEach(AppUser.Department.allCases, id: \.self) { dep in
                        Text(dep.rawValue).tag(dep)
                    }
                }
            }

            if let error = authViewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    Task {
                        await authViewModel.register(
                            email: email,
                            password: password,
                            displayName: displayName,
                            year: year,
                            department: department.rawValue
                        )
                        if authViewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Napravi nalog")
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || authViewModel.isLoading)
            }
        }
        .navigationTitle("Registracija")
        .navigationBarTitleDisplayMode(.inline)
    }
}

