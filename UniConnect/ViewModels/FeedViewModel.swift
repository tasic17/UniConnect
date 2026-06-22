import Combine
import Foundation
import FirebaseAuth

enum FeedPostImageOrderedPart {
    case keepURL(String)
    case newUpload(Data)
}

enum FeedPostImageUpdate {
    case unchanged
    case removeAll
    case modifyOrdered([FeedPostImageOrderedPart])
}

final class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var threadReplies: [String: [FeedPost]] = [:]
    @Published var loadingThreadIds: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Keš: uid → URL profilne (ili prazan string ako nema) za avatare u feed-u.
    @Published private(set) var authorProfileURLCache: [String: String] = [:]

    private enum PostOrigin {
        case main(Int)
        case thread(String)
    }

    /// Ne ponavlja mrežni poziv ako feed već ima podatke (npr. posle paralelnog prefetch-a u `MainTabView`).
    @MainActor
    func ensureFeedLoadedIfEmpty() async {
        guard posts.isEmpty else { return }
        await fetchPosts()
    }

    @MainActor
    func fetchPosts() async {
        isLoading = true
        errorMessage = nil
        do {
            posts = try await FirestoreService.shared.fetchRootFeedPosts()
            await prefetchAuthorAvatars(for: posts)
            NotificationCenter.default.post(name: .feedPostsDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Učitava `users/{uid}` za avatar ako u postu nema `authorProfileImageURL` (starije objave / drugi korisnici).
    @MainActor
    func ensureAuthorAvatarLoaded(authorId: String) async {
        if authorProfileURLCache[authorId] != nil { return }
        if authorId == Auth.auth().currentUser?.uid,
           let me = try? await AuthService.shared.fetchCurrentUser(),
           let url = me.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            authorProfileURLCache[authorId] = url
            return
        }
        guard let user = try? await AuthService.shared.fetchUser(uid: authorId) else {
            authorProfileURLCache[authorId] = ""
            return
        }
        let u = user.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        authorProfileURLCache[authorId] = u.isEmpty ? "" : u
    }

    @MainActor
    private func prefetchAuthorAvatars(for feedPosts: [FeedPost]) async {
        let ids = Set(feedPosts.map(\.authorId))
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    guard let self else { return }
                    await self.ensureAuthorAvatarLoaded(authorId: id)
                }
            }
        }
    }

    @MainActor
    func loadThread(rootId: String, force: Bool = false) async {
        if !force, threadReplies[rootId] != nil { return }
        loadingThreadIds.insert(rootId)
        errorMessage = nil
        defer { loadingThreadIds.remove(rootId) }
        do {
            let list = try await FirestoreService.shared.fetchThreadReplies(rootId: rootId)
            threadReplies[rootId] = list
            let authors = Set(list.map(\.authorId))
            await withTaskGroup(of: Void.self) { group in
                for aid in authors {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.ensureAuthorAvatarLoaded(authorId: aid)
                    }
                }
            }
            syncRootReplyCountFromLoadedThread(rootId: rootId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func syncRootReplyCountFromLoadedThread(rootId: String) {
        let n = threadReplies[rootId]?.count ?? 0
        guard let idx = posts.firstIndex(where: { $0.id == rootId }) else { return }
        var root = posts[idx]
        root.replyCount = n
        posts[idx] = root
    }

    @MainActor
    func createPost(
        content: String,
        targetDepartment: String?,
        authorId: String,
        authorName: String,
        authorProfileImageURL: String?,
        authorDepartment: String,
        imageDatas: [Data] = []
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let post = FeedPost(
            content: trimmed,
            authorId: authorId,
            authorName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            authorDepartment: authorDepartment,
            targetDepartment: targetDepartment,
            likesCount: 0,
            likes: [],
            createdAt: Date(),
            imageURLs: nil,
            parentId: nil,
            threadRootId: nil,
            replyCount: 0
        )
        do {
            let id = try FirestoreService.shared.createFeedPost(post)
            if !imageDatas.isEmpty {
                let urls = try await StorageService.shared.uploadFeedPostImages(feedPostId: id, datas: imageDatas)
                try await FirestoreService.shared.updateFeedPostImageURLs(id: id, imageURLs: urls)
            }
            await fetchPosts()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func createReply(
        content: String,
        parentPost: FeedPost,
        parentPostId: String,
        threadRootId: String,
        authorId: String,
        authorName: String,
        authorProfileImageURL: String?,
        authorDepartment: String,
        imageDatas: [Data] = []
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootPost: FeedPost
        if let local = posts.first(where: { $0.id == threadRootId }) {
            rootPost = local
        } else {
            do {
                guard let fetched = try await FirestoreService.shared.fetchFeedPost(id: threadRootId) else {
                    errorMessage = "Korenska objava nije učitana."
                    return false
                }
                rootPost = fetched
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
        let reply = FeedPost(
            content: trimmed,
            authorId: authorId,
            authorName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            authorDepartment: authorDepartment,
            targetDepartment: rootPost.targetDepartment,
            likesCount: 0,
            likes: [],
            createdAt: Date(),
            imageURLs: nil,
            parentId: parentPostId,
            threadRootId: threadRootId,
            replyCount: nil
        )
        do {
            let replyId = try await FirestoreService.shared.createFeedReply(reply, bumpReplyCountOnRootId: threadRootId)
            if !imageDatas.isEmpty {
                let urls = try await StorageService.shared.uploadFeedPostImages(feedPostId: replyId, datas: imageDatas)
                try await FirestoreService.shared.updateFeedPostImageURLs(id: replyId, imageURLs: urls)
            }
            await loadThread(rootId: threadRootId, force: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func toggleLike(postId: String, userId: String) async {
        guard let (current, origin) = locatePost(postId: postId) else {
            errorMessage = "Objava nije učitana. Povuci feed da osvežiš pa probaj ponovo."
            return
        }
        let wasLiked = current.likes.contains(userId)
        let optimistic = toggledLike(current, userId: userId)
        applyPost(optimistic, origin: origin)
        do {
            try await FirestoreService.shared.toggleLike(
                postId: postId,
                userId: userId,
                isLiked: wasLiked
            )
        } catch {
            errorMessage = error.localizedDescription
            applyPost(current, origin: origin)
        }
    }

    private func toggledLike(_ post: FeedPost, userId: String) -> FeedPost {
        var copy = post
        let wasLiked = copy.likes.contains(userId)
        if wasLiked {
            copy.likes.removeAll { $0 == userId }
            copy.likesCount = max(0, copy.likesCount - 1)
        } else {
            copy.likes.append(userId)
            copy.likesCount += 1
        }
        return copy
    }

    private func locatePost(postId: String) -> (FeedPost, PostOrigin)? {
        if let i = posts.firstIndex(where: { $0.id == postId }) {
            return (posts[i], .main(i))
        }
        for key in threadReplies.keys {
            if let p = threadReplies[key]?.first(where: { $0.id == postId }) {
                return (p, .thread(key))
            }
        }
        return nil
    }

    private func applyPost(_ post: FeedPost, origin: PostOrigin) {
        switch origin {
        case .main(let i):
            posts[i] = post
        case .thread(let rootId):
            if var list = threadReplies[rootId], let j = list.firstIndex(where: { $0.id == post.id }) {
                list[j] = post
                threadReplies[rootId] = list
            }
        }
    }

    @MainActor
    func deletePost(_ post: FeedPost) async {
        errorMessage = nil
        do {
            try await FirestoreService.shared.deleteFeedDocument(post)
            if post.isRootPost, let id = post.id {
                threadReplies[id] = nil
            }
            await fetchPosts()
            if let rid = post.threadRootId {
                await loadThread(rootId: rid, force: true)
            }
        } catch {
            errorMessage = error.localizedDescription
            await fetchPosts()
            if let rid = post.threadRootId {
                await loadThread(rootId: rid, force: true)
            }
        }
    }

    /// Dokument za izmenu slika kada nije u lokalnom kešu (npr. otvoreno sa profila).
    @MainActor
    private func feedPostForMutation(id: String) async -> FeedPost? {
        if let p = posts.first(where: { $0.id == id }) { return p }
        for list in threadReplies.values {
            if let p = list.first(where: { $0.id == id }) { return p }
        }
        return try? await FirestoreService.shared.fetchFeedPost(id: id)
    }

    @MainActor
    func updateFeedPost(
        id: String,
        content: String,
        imageUpdate: FeedPostImageUpdate
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Tekst ne sme biti prazan."
            return false
        }
        do {
            let oldURLs = (await feedPostForMutation(id: id))?.feedImageURLs ?? []
            switch imageUpdate {
            case .unchanged:
                try await FirestoreService.shared.updateFeedPostContent(id: id, content: trimmed)
            case .removeAll:
                await StorageService.shared.deleteDownloadURLs(oldURLs)
                try await FirestoreService.shared.updateFeedPostContentAndImages(id: id, content: trimmed, imageURLs: [])
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
                        let url = try await StorageService.shared.uploadFeedPostImageUnique(feedPostId: id, data: data)
                        finalURLs.append(url)
                    }
                }
                try await FirestoreService.shared.updateFeedPostContentAndImages(id: id, content: trimmed, imageURLs: finalURLs)
            }
            await fetchPosts()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

extension Notification.Name {
    /// Posle uspešnog `fetchPosts()` u feed-u — profil može da osveži listu korenskih objava.
    static let feedPostsDidChange = Notification.Name("UniConnect.feedPostsDidChange")
}
