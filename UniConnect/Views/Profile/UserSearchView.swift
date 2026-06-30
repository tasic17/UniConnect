import SwiftUI

enum UserSearchMode {
    /// Pretraga svih korisnika → profil + zaprati.
    case discoverAll
    /// Samo praćeni korisnici → pokreni / otvori chat.
    case pickFollowedForChat
    /// Praćeni + pretraga → pošalji sadržaj u chat.
    case pickUserForShare
}

struct UserSearchView: View {
    let mode: UserSearchMode
    var embeddedInSheet: Bool = false
    var onPickUserForChat: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var followVM: FollowViewModel
    @EnvironmentObject private var authorCache: AuthorProfileCache

    @State private var query = ""
    @State private var results: [AppUser] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding()

            Group {
                if mode == .pickFollowedForChat || mode == .pickUserForShare {
                    sharePickerContent
                } else {
                    discoverContent
                }
            }
        }
        .background(Constants.Colors.background)
        .navigationTitle(embeddedInSheet ? "" : navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !embeddedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zatvori") { dismiss() }
                }
            }
        }
        .navigationDestination(for: AuthorProfileNavigationID.self) { target in
            UserProfileView(userId: target.userId)
        }
        .task(id: authViewModel.currentUser?.uid) {
            guard let uid = authViewModel.currentUser?.uid else { return }
            await followVM.ensureFollowingLoaded(userId: uid)
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .discoverAll: return "Pretraga korisnika"
        case .pickFollowedForChat: return "Novo ćaskanje"
        case .pickUserForShare: return "Izaberi primaoca"
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(searchPlaceholder, text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: query) { _, newValue in
                    scheduleSearch(text: newValue)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    searchError = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var searchPlaceholder: String {
        switch mode {
        case .discoverAll: return "Ime, prezime ili smer…"
        case .pickFollowedForChat: return "Filtriraj praćene…"
        case .pickUserForShare: return "Ime ili filtriraj praćene…"
        }
    }

    @ViewBuilder
    private var discoverContent: some View {
        if isSearching {
            ProgressView("Pretraga…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let searchError {
            Text(searchError)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            VStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Unesi bar 2 karaktera")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            Text("Nema rezultata.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(results) { user in
                NavigationLink(value: AuthorProfileNavigationID(userId: user.uid)) {
                    UserSearchRow(user: user)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var sharePickerContent: some View {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .pickUserForShare, trimmedQuery.count >= 2 {
            shareSearchResults
        } else {
            followedPickerList
        }
    }

    @ViewBuilder
    private var shareSearchResults: some View {
        if isSearching {
            ProgressView("Pretraga…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let searchError {
            Text(searchError)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            Text("Nema rezultata.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(results) { user in
                Button {
                    onPickUserForChat?(user.uid)
                } label: {
                    UserSearchRow(user: user)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var followedPickerList: some View {
        let filtered = filteredFollowingUsers()
        if followVM.isLoading && followVM.followingUsers.isEmpty {
            ProgressView("Učitavanje…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if followVM.followingUsers.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "person.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Još nikoga ne pratiš")
                    .font(.headline)
                Text("U tabu Objave koristi pretragu (lupa) da nađeš korisnike i zapratiš ih.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            Text("Nema praćenih za „\(query)”.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filtered, id: \.targetUserId) { follow in
                Button {
                    onPickUserForChat?(follow.targetUserId)
                    if mode == .pickFollowedForChat {
                        dismiss()
                    }
                } label: {
                    UserFollowRow(
                        follow: follow,
                        actionHint: mode == .pickUserForShare ? "Pošalji" : "Dodirni za ćaskanje"
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func filteredFollowingUsers() -> [UserFollow] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return followVM.followingUsers }
        return followVM.followingUsers.filter {
            let name = authorCache.resolvedName(for: $0.targetUserId, fallback: $0.displayName)
            return name.localizedCaseInsensitiveContains(needle)
        }
    }

    private func scheduleSearch(text: String) {
        searchTask?.cancel()
        guard mode == .discoverAll || mode == .pickUserForShare else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            searchError = nil
            isSearching = false
            return
        }
        isSearching = true
        searchError = nil
        let exclude = authViewModel.currentUser?.uid
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let found = try await FirestoreService.shared.searchUsers(
                    matching: trimmed,
                    excludingUserId: exclude
                )
                await MainActor.run {
                    results = found
                    isSearching = false
                    for user in found {
                        authorCache.seed(user: user)
                    }
                }
            } catch {
                await MainActor.run {
                    searchError = error.localizedDescription
                    results = []
                    isSearching = false
                }
            }
        }
    }
}

private struct UserSearchRow: View {
    let user: AppUser

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarImage(
                imageURL: user.profileImageURL,
                name: user.displayName,
                size: 44
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(DisplayNameFormat.firstLast(from: user.displayName))
                    .font(.headline)
                Text(user.department)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(user.year). godina")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct UserFollowRow: View {
    let follow: UserFollow
    var actionHint: String = "Dodirni za ćaskanje"

    @EnvironmentObject private var authorCache: AuthorProfileCache

    private var name: String {
        authorCache.resolvedName(for: follow.targetUserId, fallback: follow.displayName)
    }

    private var photoURL: String? {
        authorCache.photoURL(for: follow.targetUserId) ?? follow.profileImageURL
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarImage(
                imageURL: photoURL,
                name: name,
                size: 44
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(DisplayNameFormat.firstLast(from: name))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(actionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "message.fill")
                .foregroundStyle(Constants.Colors.primary)
        }
        .padding(.vertical, 4)
        .task(id: follow.targetUserId) {
            await authorCache.refresh(authorId: follow.targetUserId)
        }
    }
}
