import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var displayName: String
    @State private var year: Int
    @State private var department: AppUser.Department
    @State private var bio: String

    init(user: AppUser) {
        _displayName = State(initialValue: user.displayName)
        _year = State(initialValue: user.year)
        _department = State(initialValue: AppUser.Department(rawValue: user.department) ?? .softversko)
        _bio = State(initialValue: user.bio ?? "")
    }

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Osnovno") {
                    TextField("Ime i prezime", text: $displayName)
                        .textInputAutocapitalization(.words)
                }

                Section("Studije") {
                    Stepper("Godina: \(year)", value: $year, in: 1...6)
                    Picker("Smer", selection: $department) {
                        ForEach(AppUser.Department.allCases, id: \.self) { dep in
                            Text(dep.rawValue).tag(dep)
                        }
                    }
                }

                Section("Bio") {
                    TextField("Kratak opis (opciono)", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let err = authViewModel.errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Uredi profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sačuvaj") {
                        Task {
                            let ok = await authViewModel.updateProfile(
                                displayName: displayName,
                                year: year,
                                department: department.rawValue,
                                bio: bio
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!isValid || authViewModel.isLoading)
                }
            }
            .overlay {
                if authViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}
