import FirebaseFirestore
import SwiftUI

struct ProfileConnectionsListView: View {
    let userId: String
    let kind: ProfileConnectionKind

    @State private var following: [UserFollow] = []
    @State private var followers: [UserFollower] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var listener: ListenerRegistration?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Učitavanje…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                VStack(spacing: 12) {
                    Text(friendlyError(loadError))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Pokušaj ponovo") {
                        startListening()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: kind == .followers ? "person.2" : "person.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(emptyTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if kind == .following {
                        ForEach(following) { entry in
                            NavigationLink(value: AuthorProfileNavigationID(userId: entry.targetUserId)) {
                                connectionRow(
                                    name: entry.displayName,
                                    photoURL: entry.profileImageURL
                                )
                            }
                        }
                    } else {
                        ForEach(followers) { entry in
                            NavigationLink(value: AuthorProfileNavigationID(userId: entry.followerUserId)) {
                                connectionRow(
                                    name: entry.displayName,
                                    photoURL: entry.profileImageURL
                                )
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Constants.Colors.background)
        .navigationTitle(kind == .followers ? "Pratioci" : "Pratiš")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AuthorProfileNavigationID.self) { target in
            UserProfileView(userId: target.userId)
        }
        .onAppear { startListening() }
        .onDisappear { stopListening() }
        .refreshable { await reloadOnce() }
    }

    private var isEmpty: Bool {
        kind == .following ? following.isEmpty : followers.isEmpty
    }

    private var emptyTitle: String {
        kind == .followers ? "Nema pratilaca" : "Nikoga ne prati"
    }

    private func connectionRow(name: String, photoURL: String?) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarImage(imageURL: photoURL, name: name, size: 44)
            Text(DisplayNameFormat.firstLast(from: name))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func friendlyError(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("permission") {
            return "Nema dozvole za čitanje liste. Objavi najnovija Firestore pravila u Firebase konzoli (sekcija followers)."
        }
        return message
    }

    private func startListening() {
        stopListening()
        isLoading = true
        loadError = nil

        switch kind {
        case .following:
            listener = FirestoreService.shared.listenFollowing(userId: userId) { list in
                following = list
                followers = []
                isLoading = false
                loadError = nil
            } onError: { error in
                isLoading = false
                loadError = error.localizedDescription
                following = []
            }
        case .followers:
            listener = FirestoreService.shared.listenFollowers(userId: userId) { list in
                followers = list
                following = []
                isLoading = false
                loadError = nil
            } onError: { error in
                isLoading = false
                loadError = error.localizedDescription
                followers = []
            }
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func reloadOnce() async {
        do {
            switch kind {
            case .following:
                following = try await FirestoreService.shared.fetchFollowing(userId: userId)
            case .followers:
                followers = try await FirestoreService.shared.fetchFollowers(userId: userId)
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}
