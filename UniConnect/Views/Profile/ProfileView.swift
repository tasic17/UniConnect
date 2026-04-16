import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if let user = authViewModel.currentUser {
                    profileScroll(user: user)
                } else if authViewModel.isLoading {
                    ProgressView("Učitavanje profila…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Profil nije učitan")
                            .font(.headline)
                        Text("Povuci za osvežavanje ili dodirni strelicu za ponovno učitavanje.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Constants.Colors.background)
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if authViewModel.currentUser != nil {
                        Button("Uredi") {
                            authViewModel.errorMessage = nil
                            showEditProfile = true
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await authViewModel.fetchCurrentUser() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Osveži profil")
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let user = authViewModel.currentUser {
                    EditProfileView(user: user)
                        .environmentObject(authViewModel)
                }
            }
            .task {
                await authViewModel.fetchCurrentUser()
            }
            .refreshable {
                await authViewModel.fetchCurrentUser()
            }
        }
    }

    private func profileScroll(user: AppUser) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                avatarBlock(for: user)

                VStack(alignment: .leading, spacing: 12) {
                    profileRow(title: "Ime", value: user.displayName, icon: "person.fill")
                    profileRow(title: "Email", value: user.email, icon: "envelope.fill")
                    profileRow(title: "Godina", value: "\(user.year). godina", icon: "graduationcap.fill")
                    profileRow(title: "Smer", value: user.department, icon: "books.vertical.fill")

                    profileRow(title: "Bio", value: bioDisplayText(for: user), icon: "text.alignleft")

                    profileRow(
                        title: "Član od",
                        value: user.createdAt.formatted(date: .long, time: .omitted),
                        icon: "calendar"
                    )
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let message = authViewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(role: .destructive) {
                    authViewModel.logout()
                } label: {
                    Text("Odjavi se")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.85))
            }
            .padding()
        }
    }

    private func avatarBlock(for user: AppUser) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.primary.opacity(0.15))
                    .frame(width: 96, height: 96)
                Text(initials(from: user.displayName))
                    .font(.title.bold())
                    .foregroundStyle(Constants.Colors.primary)
            }
            Text(user.displayName)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
    }

    private func profileRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Constants.Colors.primary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
    }

    private func bioDisplayText(for user: AppUser) -> String {
        let b = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return b.isEmpty ? "—" : b
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
