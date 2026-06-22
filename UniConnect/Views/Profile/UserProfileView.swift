import SwiftUI

/// Pregled tuđeg (ili sopstvenog) profila iz feeda / oglasa / događaja.
struct UserProfileView: View {
    let userId: String
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var boardVM: BoardViewModel

    @State private var user: AppUser?
    @State private var isLoading = true
    @State private var loadError: String?

    private var isMe: Bool {
        authViewModel.currentUser?.uid == userId
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Učitavanje…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let user {
                profileContent(user: user)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(loadError ?? "Profil nije pronađen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Constants.Colors.background)
        .navigationTitle(user?.displayName ?? "Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userId) {
            await load()
        }
    }

    @ViewBuilder
    private func profileContent(user: AppUser) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                avatarSection(for: user)

                VStack(alignment: .leading, spacing: 12) {
                    profileRow(title: "Ime", value: user.displayName, icon: "person.fill")
                    if isMe {
                        profileRow(title: "Email", value: user.email, icon: "envelope.fill")
                    }
                    profileRow(title: "Godina", value: "\(user.year). godina", icon: "graduationcap.fill")
                    profileRow(title: "Smer", value: user.department, icon: "books.vertical.fill")
                    profileRow(title: "Bio", value: bioText(user.bio), icon: "text.alignleft")
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

                if !isMe {
                    Text("Kontakt email je vidljiv samo vlasniku naloga.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ProfileUserPostsSection(userId: user.uid, isMe: isMe)

                ProfileUserFeedPostsSection(userId: user.uid, isMe: isMe)
            }
            .padding()
        }
        .refreshable {
            await load()
            NotificationCenter.default.post(name: .boardPostsDidChange, object: nil)
            NotificationCenter.default.post(name: .feedPostsDidChange, object: nil)
        }
    }

    private func avatarSection(for user: AppUser) -> some View {
        VStack(spacing: 12) {
            let urlStr = user.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let urlStr, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        avatarPlaceholder(name: user.displayName)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        avatarPlaceholder(name: user.displayName)
                    }
                }
                .id(urlStr)
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            } else {
                avatarPlaceholder(name: user.displayName)
            }
            Text(user.displayName)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
    }

    private func avatarPlaceholder(name: String) -> some View {
        ZStack {
            Circle()
                .fill(Constants.Colors.primary.opacity(0.15))
                .frame(width: 96, height: 96)
            Text(initials(from: name))
                .font(.title.bold())
                .foregroundStyle(Constants.Colors.primary)
        }
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

    private func bioText(_ bio: String?) -> String {
        let b = bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return b.isEmpty ? "—" : b
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        if userId == authViewModel.currentUser?.uid, let u = authViewModel.currentUser {
            user = u
            do {
                if let fresh = try await AuthService.shared.fetchCurrentUser() {
                    user = fresh
                }
            } catch {
                loadError = error.localizedDescription
            }
            return
        }
        do {
            user = try await AuthService.shared.fetchUser(uid: userId)
            if user == nil {
                loadError = "Korisnik ne postoji."
            }
        } catch {
            loadError = error.localizedDescription
            user = nil
        }
    }
}
