import SwiftUI

enum MainTab: Int, Hashable {
    case events = 0
    case board = 1
    case feed = 2
    case messages = 3
    case profile = 4
    case admin = 5
}

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var eventsVM = EventsViewModel()
    @StateObject private var boardVM = BoardViewModel()
    @StateObject private var feedVM = FeedViewModel()
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var followVM = FollowViewModel()
    @StateObject private var authorCache = AuthorProfileCache()
    @State private var selectedTab: MainTab = .events

    private var unreadMessagesBadge: Int {
        guard let uid = authViewModel.currentUser?.uid else { return 0 }
        return chatVM.totalUnread(for: uid)
    }

    /// Paralelno učitava glavne liste pre prvog otvorenog taba — tabovi zovu `ensure*LoadedIfEmpty()` da ne dupliraju mrežu.
    @MainActor
    private func prefetchAllTabs() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await eventsVM.fetchEvents() }
            group.addTask { await boardVM.fetchPosts() }
            group.addTask { await feedVM.fetchPosts() }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            EventsView()
                .environmentObject(eventsVM)
                .tabItem { Label("Dogadjaji", systemImage: "calendar") }
                .tag(MainTab.events)

            BoardView()
                .environmentObject(boardVM)
                .tabItem { Label("Oglasi", systemImage: "square.grid.2x2") }
                .tag(MainTab.board)

            FeedView()
                .environmentObject(feedVM)
                .tabItem { Label("Objave", systemImage: "bubble.left.and.bubble.right") }
                .tag(MainTab.feed)

            MessagesView(selectedTab: $selectedTab)
                .tabItem { Label("Poruke", systemImage: "message") }
                .badge(unreadMessagesBadge)
                .tag(MainTab.messages)

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.circle") }
                .tag(MainTab.profile)

            if authViewModel.isAdmin {
                AdminView()
                    .tabItem { Label("Admin", systemImage: "shield.fill") }
                    .tag(MainTab.admin)
            }
        }
        .tint(Constants.Colors.primary)
        .environmentObject(boardVM)
        .environmentObject(eventsVM)
        .environmentObject(feedVM)
        .environmentObject(chatVM)
        .environmentObject(followVM)
        .environmentObject(authorCache)
        .task {
            await prefetchAllTabs()
        }
        .task(id: authViewModel.currentUser?.uid) {
            guard let uid = authViewModel.currentUser?.uid else { return }
            if let user = authViewModel.currentUser {
                await FollowMirrorMigration.runIfNeeded(for: user)
            }
            chatVM.ensureChatsListening(userId: uid)
            await followVM.ensureFollowingLoaded(userId: uid)
            followVM.startWatchingCounts(for: uid)
        }
        .onChange(of: authViewModel.currentUser?.uid) { _, newUid in
            followVM.startWatchingCounts(for: newUid)
        }
        .onChange(of: chatVM.pendingOpenChatId) { _, chatId in
            if chatId != nil {
                selectedTab = .messages
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileDidUpdate)) { notification in
            guard let uid = notification.object as? String else { return }
            authorCache.invalidate(authorId: uid)
            Task {
                await authorCache.refresh(authorId: uid)
                await chatVM.refreshParticipantProfile(userId: uid)
            }
        }
    }
}
