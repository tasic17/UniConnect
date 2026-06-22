import FirebaseFirestore
import SwiftUI

/// Pregled tuđeg (ili sopstvenog) profila iz feeda / oglasa / događaja.
struct UserProfileView: View {
    let userId: String
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var boardVM: BoardViewModel
    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var followVM: FollowViewModel

    @State private var user: AppUser?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var isOpeningChat = false
    @State private var isFollowBusy = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var countListeners: [ListenerRegistration] = []

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
        .navigationDestination(for: ProfileConnectionsNavigationID.self) { nav in
            ProfileConnectionsListView(userId: nav.userId, kind: nav.kind)
        }
        .navigationDestination(for: AuthorProfileNavigationID.self) { target in
            UserProfileView(userId: target.userId)
        }
        .task(id: userId) {
            await load()
            if let uid = authViewModel.currentUser?.uid {
                await followVM.ensureFollowingLoaded(userId: uid)
            }
        }
        .onAppear { startCountListenersIfNeeded() }
        .onDisappear { stopCountListeners() }
        .onChange(of: followVM.followersCount) { _, value in
            if isMe { followersCount = value }
        }
        .onChange(of: followVM.followingCount) { _, value in
            if isMe { followingCount = value }
        }
    }

    @ViewBuilder
    private func profileContent(user: AppUser) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                avatarSection(for: user)

                ProfileStatsRow(
                    userId: user.uid,
                    followersCount: isMe ? followVM.followersCount : followersCount,
                    followingCount: isMe ? followVM.followingCount : followingCount
                )

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

                    Button {
                        Task { await toggleFollow(target: user) }
                    } label: {
                        if isFollowBusy {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if followVM.isFollowing(user.uid) {
                            Label("Prestani da pratiš", systemImage: "person.badge.minus")
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Zaprati", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isFollowBusy || authViewModel.currentUser == nil)

                    Button {
                        Task { await openDirectMessage() }
                    } label: {
                        if isOpeningChat {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Pošalji poruku", systemImage: "message.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Constants.Colors.primary)
                    .disabled(isOpeningChat || authViewModel.currentUser == nil)
                }

                ProfileUserPostsSection(userId: user.uid, isMe: isMe)

                ProfileUserFeedPostsSection(userId: user.uid, isMe: isMe)
            }
            .padding()
        }
        .refreshable {
            await load()
            if isMe {
                if let uid = authViewModel.currentUser?.uid {
                    await followVM.reloadFollowing(userId: uid)
                }
            } else {
                await loadConnectionCountsOnce()
            }
            NotificationCenter.default.post(name: .boardPostsDidChange, object: nil)
            NotificationCenter.default.post(name: .feedPostsDidChange, object: nil)
        }
    }

    private func avatarSection(for user: AppUser) -> some View {
        VStack(spacing: 12) {
            ProfileAvatarImage(
                imageURL: user.profileImageURL,
                name: user.displayName,
                size: 96
            )
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

    private func openDirectMessage() async {
        guard let uid = authViewModel.currentUser?.uid else { return }
        isOpeningChat = true
        defer { isOpeningChat = false }
        if let chatId = await chatVM.openChat(
            currentUserId: uid,
            otherUserId: userId,
            postId: nil,
            postTitle: nil
        ) {
            chatVM.requestOpenChat(chatId: chatId)
        }
    }

    private func toggleFollow(target: AppUser) async {
        guard let me = authViewModel.currentUser else { return }
        isFollowBusy = true
        defer { isFollowBusy = false }
        if followVM.isFollowing(target.uid) {
            _ = await followVM.unfollow(currentUserId: me.uid, targetUserId: target.uid)
        } else {
            _ = await followVM.follow(currentUser: me, target: target)
        }
    }

    private func startCountListenersIfNeeded() {
        stopCountListeners()
        if isMe {
            followersCount = followVM.followersCount
            followingCount = followVM.followingCount
            return
        }
        countListeners = FirestoreService.shared.listenConnectionCounts(userId: userId) { followers, following in
            Task { @MainActor in
                followersCount = followers
                followingCount = following
            }
        }
    }

    private func stopCountListeners() {
        countListeners.forEach { $0.remove() }
        countListeners = []
    }

    private func loadConnectionCountsOnce() async {
        do {
            let counts = try await FirestoreService.shared.fetchConnectionCounts(userId: userId)
            followersCount = counts.followers
            followingCount = counts.following
        } catch {
            followersCount = 0
            followingCount = 0
        }
    }
}
