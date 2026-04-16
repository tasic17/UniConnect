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

    func fetchPosts() async throws -> [Post] {
        let snapshot = try await db.collection(Constants.Firestore.posts)
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }

    func createPost(_ post: Post) async throws {
        try db.collection(Constants.Firestore.posts).addDocument(from: post)
    }

    func deletePost(id: String) async throws {
        try await db.collection(Constants.Firestore.posts).document(id).delete()
    }

    // MARK: - Feed

    func fetchFeedPosts() async throws -> [FeedPost] {
        let snapshot = try await db.collection(Constants.Firestore.feedPosts)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: FeedPost.self) }
    }

    func createFeedPost(_ post: FeedPost) async throws {
        try db.collection(Constants.Firestore.feedPosts).addDocument(from: post)
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
}
