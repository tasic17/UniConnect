import SwiftUI

struct MainTabView: View {
    @StateObject private var eventsVM = EventsViewModel()

    var body: some View {
        TabView {
            EventsView()
                .environmentObject(eventsVM)
                .tabItem { Label("Dogadjaji", systemImage: "calendar") }

            Text("Oglasi")
                .tabItem { Label("Oglasi", systemImage: "square.grid.2x2") }

            Text("Feed")
                .tabItem { Label("Feed", systemImage: "bubble.left.and.bubble.right") }

            Text("Poruke")
                .tabItem { Label("Poruke", systemImage: "message") }

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.circle") }
        }
        .tint(Constants.Colors.primary)
    }
}

