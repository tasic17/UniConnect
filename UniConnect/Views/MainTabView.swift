import SwiftUI

struct MainTabView: View {
    @StateObject private var eventsVM = EventsViewModel()
    @StateObject private var boardVM = BoardViewModel()
    @StateObject private var feedVM = FeedViewModel()

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
        TabView {
            EventsView()
                .environmentObject(eventsVM)
                .tabItem { Label("Dogadjaji", systemImage: "calendar") }

            BoardView()
                .environmentObject(boardVM)
                .tabItem { Label("Oglasi", systemImage: "square.grid.2x2") }

            FeedView()
                .environmentObject(feedVM)
                .tabItem { Label("Objave", systemImage: "bubble.left.and.bubble.right") }

            Text("Poruke")
                .tabItem { Label("Poruke", systemImage: "message") }

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.circle") }
        }
        .tint(Constants.Colors.primary)
        .environmentObject(boardVM)
        .environmentObject(feedVM)
        .task {
            await prefetchAllTabs()
        }
    }
}

