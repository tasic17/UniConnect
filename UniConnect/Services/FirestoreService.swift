import Foundation
import FirebaseFirestore

/// Centralizovani Firestore pozivi za događaje, oglase i feed (bez Firebase koda u View-ovima).
final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    // MARK: - Events

    func fetchEvents() async throws -> [Event] {
        let snapshot = try await db.collection(Constants.Firestore.events)
            .order(by: "date", descending: false)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Event.self) }
    }

    func createEvent(_ event: Event) async throws {
        try db.collection(Constants.Firestore.events).addDocument(from: event)
    }

    func deleteEvent(id: String) async throws {
        try await db.collection(Constants.Firestore.events).document(id).delete()
    }

    func updateEvent(
        id: String,
        title: String,
        description: String,
        category: Event.EventCategory,
        date: Date,
        location: String,
        latitude: Double?,
        longitude: Double?
    ) async throws {
        let ref = db.collection(Constants.Firestore.events).document(id)
        var data: [String: Any] = [
            "title": title,
            "description": description,
            "category": category.rawValue,
            "date": Timestamp(date: date),
            "location": location
        ]
        if let lat = latitude, let lon = longitude {
            data["latitude"] = lat
            data["longitude"] = lon
        } else {
            data["latitude"] = FieldValue.delete()
            data["longitude"] = FieldValue.delete()
        }
        try await ref.updateData(data)
    }

    /// `isCurrentlyAttending` = da li je korisnik već u `attendees` (ukloni ga), inače dodaj.
    func toggleRSVP(eventId: String, userId: String, isCurrentlyAttending: Bool) async throws {
        let ref = db.collection(Constants.Firestore.events).document(eventId)
        if isCurrentlyAttending {
            try await ref.updateData([
                "attendees": FieldValue.arrayRemove([userId]),
                "attendeesCount": FieldValue.increment(Int64(-1))
            ])
        } else {
            try await ref.updateData([
                "attendees": FieldValue.arrayUnion([userId]),
                "attendeesCount": FieldValue.increment(Int64(1))
            ])
        }
    }

    // MARK: - Posts (oglasi)

    /// Aktivne oglase filtriramo na klijentu da izbegnemo kompozitni indeks (`isActive` + `createdAt`).
    func fetchPosts() async throws -> [Post] {
        let snapshot = try await db.collection(Constants.Firestore.posts)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents
            .compactMap { try $0.data(as: Post.self) }
            .filter(\.isActive)
    }

    @discardableResult
    func createPost(_ post: Post) throws -> String {
        let ref = try db.collection(Constants.Firestore.posts).addDocument(from: post)
        return ref.documentID
    }

    /// `imageURLs == nil` — ne menja slike (samo tekst i ostalo).
    func updatePost(
        id: String,
        title: String,
        description: String,
        category: Post.PostCategory,
        price: Double?,
        imageURLs: [String]?
    ) async throws {
        var data: [String: Any] = [
            "title": title,
            "description": description,
            "category": category.rawValue
        ]
        if let price {
            data["price"] = price
        } else {
            data["price"] = FieldValue.delete()
        }
        if let imageURLs {
            data["imageURLs"] = imageURLs
        }
        try await db.collection(Constants.Firestore.posts).document(id).updateData(data)
    }

    func deletePost(id: String) async throws {
        try await db.collection(Constants.Firestore.posts).document(id).delete()
    }

    func fetchPost(id: String) async throws -> Post? {
        let doc = try await db.collection(Constants.Firestore.posts).document(id).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: Post.self)
    }

    /// Svi oglasi autora (aktivni i neaktivni); sort po `createdAt` na klijentu da ne zahteva kompozitni indeks.
    func fetchPostsByAuthor(authorId: String) async throws -> [Post] {
        let snapshot = try await db.collection(Constants.Firestore.posts)
            .whereField("authorId", isEqualTo: authorId)
            .getDocuments()
        let items = try snapshot.documents.compactMap { try $0.data(as: Post.self) }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Feed

    /// Sve objave (koreni + odgovori), najnovije prvo — za feed se filtriraju samo koreni na klijentu.
    func fetchAllFeedDocuments() async throws -> [FeedPost] {
        let snapshot = try await db.collection(Constants.Firestore.feedPosts)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: FeedPost.self) }
    }

    /// Samo korenski postovi (bez `parentId`). Skalabilnije: kasnije `whereField` + indeks.
    func fetchRootFeedPosts() async throws -> [FeedPost] {
        try await fetchAllFeedDocuments().filter(\.isRootPost)
    }

    func fetchFeedPost(id: String) async throws -> FeedPost? {
        let doc = try await db.collection(Constants.Firestore.feedPosts).document(id).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: FeedPost.self)
    }

    /// Odgovori u thread-u (korenski dokument se učitava odvojeno).
    /// Sortiranje je na klijentu da ne zahteva kompozitni indeks (`threadRootId` + `createdAt`).
    func fetchThreadReplies(rootId: String) async throws -> [FeedPost] {
        let snapshot = try await db.collection(Constants.Firestore.feedPosts)
            .whereField("threadRootId", isEqualTo: rootId)
            .getDocuments()
        let items = try snapshot.documents.compactMap { try $0.data(as: FeedPost.self) }
        return items.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func createFeedPost(_ post: FeedPost) throws -> String {
        let ref = try db.collection(Constants.Firestore.feedPosts).addDocument(from: post)
        return ref.documentID
    }

    func updateFeedPostImageURLs(id: String, imageURLs: [String]) async throws {
        try await db.collection(Constants.Firestore.feedPosts).document(id).updateData([
            "imageURLs": imageURLs
        ])
    }

    /// Korenske objave korisnika (feed), sortirano na klijentu.
    func fetchRootFeedPostsByAuthor(authorId: String) async throws -> [FeedPost] {
        let snapshot = try await db.collection(Constants.Firestore.feedPosts)
            .whereField("authorId", isEqualTo: authorId)
            .getDocuments()
        let items = try snapshot.documents.compactMap { try $0.data(as: FeedPost.self) }
        return items
            .filter(\.isRootPost)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func updateFeedPostContent(id: String, content: String) async throws {
        try await db.collection(Constants.Firestore.feedPosts).document(id).updateData([
            "content": content
        ])
    }

    func updateFeedPostContentAndImages(id: String, content: String, imageURLs: [String]) async throws {
        try await db.collection(Constants.Firestore.feedPosts).document(id).updateData([
            "content": content,
            "imageURLs": imageURLs
        ])
    }

    @discardableResult
    func createFeedReply(_ reply: FeedPost, bumpReplyCountOnRootId rootId: String) async throws -> String {
        let ref = try db.collection(Constants.Firestore.feedPosts).addDocument(from: reply)
        try await db.collection(Constants.Firestore.feedPosts).document(rootId).updateData([
            "replyCount": FieldValue.increment(Int64(1))
        ])
        return ref.documentID
    }

    /// `isLiked` = da li je korisnik već u `likes` (ukloni lajk), inače dodaj.
    func toggleLike(postId: String, userId: String, isLiked: Bool) async throws {
        let ref = db.collection(Constants.Firestore.feedPosts).document(postId)
        if isLiked {
            try await ref.updateData([
                "likes": FieldValue.arrayRemove([userId]),
                "likesCount": FieldValue.increment(Int64(-1))
            ])
        } else {
            try await ref.updateData([
                "likes": FieldValue.arrayUnion([userId]),
                "likesCount": FieldValue.increment(Int64(1))
            ])
        }
    }

    /// Briše jedan dokument ili ceo thread (koren + svi odgovori); briše i slike u Storage-u.
    func deleteFeedDocument(_ post: FeedPost) async throws {
        guard let id = post.id else { return }
        let col = db.collection(Constants.Firestore.feedPosts)
        var imageURLsToPurge: [String] = post.feedImageURLs

        if post.isRootPost {
            let repliesSnap = try await col
                .whereField("threadRootId", isEqualTo: id)
                .getDocuments()
            for doc in repliesSnap.documents {
                if let rp = try? doc.data(as: FeedPost.self) {
                    imageURLsToPurge.append(contentsOf: rp.feedImageURLs)
                }
            }
            let batch = db.batch()
            for doc in repliesSnap.documents {
                batch.deleteDocument(doc.reference)
            }
            batch.deleteDocument(col.document(id))
            try await batch.commit()
            await StorageService.shared.deleteDownloadURLs(imageURLsToPurge)
        } else {
            try await col.document(id).delete()
            if let rootId = post.threadRootId {
                try await col.document(rootId).updateData([
                    "replyCount": FieldValue.increment(Int64(-1))
                ])
            }
            await StorageService.shared.deleteDownloadURLs(imageURLsToPurge)
        }
    }
}
