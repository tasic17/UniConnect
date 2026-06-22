import Combine
import Foundation

enum PostImageOrderedPart {
    case keepURL(String)
    case newUpload(Data)
}

enum PostImageUpdate {
    /// Tekstualna polja; slike u Firestore-u se ne diraju.
    case unchanged
    /// Briše sve slike (i fajlove u Storage ako postoje URL-ovi).
    case removeAll
    /// Redosled u nizu = redosled u oglasu; zadrži postojeće URL-ove, upload samo za `newUpload`.
    case modifyOrdered([PostImageOrderedPart])
}

final class BoardViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: Post.PostCategory?
    @Published var searchText = ""

    var filteredPosts: [Post] {
        var result = posts
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(q)
                    || $0.description.localizedCaseInsensitiveContains(q)
            }
        }
        return result
    }

    /// Izbegava dupli fetch kad su oglasi već učitani u pozadini (`MainTabView`).
    @MainActor
    func ensureBoardLoadedIfEmpty() async {
        guard posts.isEmpty else { return }
        await fetchPosts()
    }

    @MainActor
    func fetchPosts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            posts = try await FirestoreService.shared.fetchPosts()
            NotificationCenter.default.post(name: .boardPostsDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Slika oglasa za brisanje / izmenu slika kada dokument možda nije u `posts` kešu.
    @MainActor
    private func postForMutation(id: String) async -> Post? {
        if let p = posts.first(where: { $0.id == id }) { return p }
        return try? await FirestoreService.shared.fetchPost(id: id)
    }

    @MainActor
    func createPost(
        title: String,
        description: String,
        category: Post.PostCategory,
        price: Double?,
        department: String?,
        authorId: String,
        authorName: String,
        imageDatas: [Data]
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let post = Post(
            title: title,
            description: description,
            category: category,
            authorId: authorId,
            authorName: authorName,
            price: price,
            imageURLs: [],
            isActive: true,
            department: department,
            createdAt: Date()
        )
        do {
            let id = try FirestoreService.shared.createPost(post)
            if !imageDatas.isEmpty {
                let urls = try await StorageService.shared.uploadPostImages(postId: id, datas: imageDatas)
                try await FirestoreService.shared.updatePost(
                    id: id,
                    title: title,
                    description: description,
                    category: category,
                    price: price,
                    imageURLs: urls
                )
            }
            await fetchPosts()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func updatePost(
        id: String,
        title: String,
        description: String,
        category: Post.PostCategory,
        price: Double?,
        imageUpdate: PostImageUpdate
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let oldURLs = (await postForMutation(id: id))?.imageURLs ?? []
            switch imageUpdate {
            case .unchanged:
                try await FirestoreService.shared.updatePost(
                    id: id,
                    title: title,
                    description: description,
                    category: category,
                    price: price,
                    imageURLs: nil
                )
            case .removeAll:
                await StorageService.shared.deleteDownloadURLs(oldURLs)
                try await FirestoreService.shared.updatePost(
                    id: id,
                    title: title,
                    description: description,
                    category: category,
                    price: price,
                    imageURLs: []
                )
            case .modifyOrdered(let parts):
                let keptURLs = parts.compactMap { part -> String? in
                    if case .keepURL(let u) = part { return u }
                    return nil
                }
                let removed = oldURLs.filter { !keptURLs.contains($0) }
                await StorageService.shared.deleteDownloadURLs(removed)
                var finalURLs: [String] = []
                for part in parts {
                    switch part {
                    case .keepURL(let u):
                        finalURLs.append(u)
                    case .newUpload(let data):
                        let url = try await StorageService.shared.uploadPostImageUnique(
                            postId: id,
                            data: data
                        )
                        finalURLs.append(url)
                    }
                }
                try await FirestoreService.shared.updatePost(
                    id: id,
                    title: title,
                    description: description,
                    category: category,
                    price: price,
                    imageURLs: finalURLs
                )
            }
            await fetchPosts()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func deletePost(id: String) async {
        errorMessage = nil
        let urls = (await postForMutation(id: id))?.imageURLs ?? []
        do {
            await StorageService.shared.deleteDownloadURLs(urls)
            try await FirestoreService.shared.deletePost(id: id)
            posts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Notification.Name {
    /// Posle uspešnog `fetchPosts()` — profil i drugi ekrani mogu da osveže listu oglasa autora.
    static let boardPostsDidChange = Notification.Name("UniConnect.boardPostsDidChange")
}
