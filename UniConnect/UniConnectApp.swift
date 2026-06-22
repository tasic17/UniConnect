import SwiftUI
import Firebase
import FirebaseFirestore

@main
struct UniConnectApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
        configureCaches()
    }

    /// Veći Firestore disk keš i HTTP keš za slike — brži ponovni ulaz u aplikaciju i manje mreže.
    private func configureCaches() {
        let db = Firestore.firestore()
        var settings = db.settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 200 * 1024 * 1024))
        db.settings = settings

        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 150 * 1024 * 1024,
            diskPath: "unic_connect_http_cache"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}

