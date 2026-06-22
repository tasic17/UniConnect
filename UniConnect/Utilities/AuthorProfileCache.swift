import Combine
import Foundation

/// Keš profilnih slika i imena autora (oglasi / događaji nemaju URL u dokumentu).
@MainActor
final class AuthorProfileCache: ObservableObject {
    @Published private(set) var photoURLs: [String: String] = [:]
    @Published private(set) var displayNames: [String: String] = [:]
    private var loadingIds: Set<String> = []

    func photoURL(for authorId: String) -> String? {
        let u = photoURLs[authorId] ?? ""
        return u.isEmpty ? nil : u
    }

    func resolvedName(for authorId: String, fallback: String) -> String {
        displayNames[authorId] ?? fallback
    }

    func ensureLoaded(authorId: String) async {
        guard !authorId.isEmpty, !loadingIds.contains(authorId) else { return }
        if photoURLs[authorId] != nil, displayNames[authorId] != nil { return }
        await refresh(authorId: authorId)
    }

    /// Uvek učitava sa servera (za liste pratilaca, poruke itd.).
    func refresh(authorId: String) async {
        guard !authorId.isEmpty else { return }
        guard !loadingIds.contains(authorId) else { return }
        loadingIds.insert(authorId)
        defer { loadingIds.remove(authorId) }
        if let user = try? await AuthService.shared.fetchUser(uid: authorId) {
            seed(user: user)
        }
    }

    func invalidate(authorId: String) {
        photoURLs.removeValue(forKey: authorId)
        displayNames.removeValue(forKey: authorId)
    }

    func seed(user: AppUser) {
        let photo = user.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        photoURLs[user.uid] = photo
        displayNames[user.uid] = user.displayName
    }
}
