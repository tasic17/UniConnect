import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    /// Profil pri otvaranju ekrana (za trenutnu fotografiju).
    let user: AppUser

    @State private var displayName: String
    @State private var year: Int
    @State private var department: AppUser.Department
    @State private var bio: String
    @State private var selectedPhoto: PhotosPickerItem?
    /// Preview kad korisnik izabere novu sliku pre čuvanja.
    @State private var pendingImageData: Data?
    @State private var removeProfileImage = false

    init(user: AppUser) {
        self.user = user
        _displayName = State(initialValue: user.displayName)
        _year = State(initialValue: user.year)
        _department = State(initialValue: AppUser.Department(rawValue: user.department) ?? .softversko)
        _bio = State(initialValue: user.bio ?? "")
    }

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasExistingPhoto: Bool {
        if let u = user.profileImageURL, !u.isEmpty { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    profileAvatarPreview
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Nova profilna slika", systemImage: "person.crop.circle.badge.plus")
                            .foregroundStyle(Constants.Colors.primary)
                    }
                    .onChange(of: selectedPhoto) { _, item in
                        Task {
                            pendingImageData = await PhotoImport.jpegData(from: item)
                            if pendingImageData != nil {
                                removeProfileImage = false
                            }
                        }
                    }

                    Button {
                        removeProfileImage = true
                        selectedPhoto = nil
                        pendingImageData = nil
                    } label: {
                        Label("Ukloni profilnu sliku", systemImage: "person.crop.circle.badge.minus")
                            .foregroundStyle(.red)
                    }
                    .disabled(removeProfileImage || (!hasExistingPhoto && pendingImageData == nil))
                    .opacity((!hasExistingPhoto && pendingImageData == nil && !removeProfileImage) ? 0.45 : 1)

                    if removeProfileImage {
                        Text("Trenutna slika će biti uklonjena kad sačuvaš.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Poništi uklanjanje") {
                            removeProfileImage = false
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Slika")
                }

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
                            let imageData = pendingImageData
                            let ok = await authViewModel.updateProfile(
                                displayName: displayName,
                                year: year,
                                department: department.rawValue,
                                bio: bio,
                                profileImageData: imageData,
                                removeProfileImage: removeProfileImage && imageData == nil
                            )
                            if ok {
                                await Task.yield()
                                await MainActor.run { dismiss() }
                            }
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

    @ViewBuilder
    private var profileAvatarPreview: some View {
        Group {
            if removeProfileImage {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 120)
                    Image(systemName: "person.slash.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            } else if let data = pendingImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
            } else if let urlStr = user.profileImageURL, let u = URL(string: urlStr) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        avatarPlaceholderInitials
                    default:
                        ProgressView()
                            .frame(width: 120, height: 120)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
            } else {
                avatarPlaceholderInitials
            }
        }
    }

    private var avatarPlaceholderInitials: some View {
        ZStack {
            Circle()
                .fill(Constants.Colors.primary.opacity(0.15))
                .frame(width: 120, height: 120)
            Text(initials(from: user.displayName))
                .font(.largeTitle.bold())
                .foregroundStyle(Constants.Colors.primary)
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
