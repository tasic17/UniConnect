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

    // MARK: - Chats / poruke

    func fetchChats(for userId: String) async throws -> [Chat] {
        let snapshot = try await db.collection(Constants.Firestore.chats)
            .whereField("participants", arrayContains: userId)
            .getDocuments()
        let items = try snapshot.documents.compactMap { try $0.data(as: Chat.self) }
        return items.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    /// Pronađi postojeći razgovor ili kreiraj novi (npr. sa oglasa).
    func findOrCreateChat(
        currentUserId: String,
        otherUserId: String,
        postId: String?,
        postTitle: String?
    ) async throws -> String {
        let participants = [currentUserId, otherUserId].sorted()
        let key = Chat.participantKey(for: participants, postId: postId)

        let existing = try await db.collection(Constants.Firestore.chats)
            .whereField("participants", arrayContains: currentUserId)
            .getDocuments()
        if let doc = existing.documents.first(where: { doc in
            (try? doc.data(as: Chat.self))?.participantKey == key
        }) {
            return doc.documentID
        }

        let preview = postTitle.map { "Oglas: \($0)" } ?? "Razgovor započet"
        let chat = Chat(
            participants: participants,
            participantKey: key,
            postId: postId,
            postTitle: postTitle,
            lastMessage: preview,
            lastMessageAt: Date(),
            createdAt: Date(),
            unreadCounts: [:]
        )
        let ref = try db.collection(Constants.Firestore.chats).addDocument(from: chat)
        return ref.documentID
    }

    func sendMessage(
        chatId: String,
        senderId: String,
        recipientId: String,
        text: String?,
        imageURL: String? = nil
    ) async throws {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let image = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty || !image.isEmpty else { return }

        let preview: String
        if !trimmed.isEmpty {
            preview = trimmed
        } else {
            preview = "Slika"
        }

        let chatRef = db.collection(Constants.Firestore.chats).document(chatId)
        let messageRef = chatRef.collection(Constants.Firestore.messages).document()
        let message = Message(
            senderId: senderId,
            text: trimmed,
            imageURL: image.isEmpty ? nil : image,
            createdAt: Date(),
            isRead: false
        )
        let batch = db.batch()
        try batch.setData(from: message, forDocument: messageRef)
        batch.updateData([
            "lastMessage": preview,
            "lastMessageAt": Timestamp(date: Date()),
            "unreadCounts.\(recipientId)": FieldValue.increment(Int64(1))
        ], forDocument: chatRef)
        try await batch.commit()
    }

    func deleteChat(chatId: String, userId: String) async throws {
        let chatRef = db.collection(Constants.Firestore.chats).document(chatId)
        let chatDoc = try await chatRef.getDocument()
        guard let chat = try? chatDoc.data(as: Chat.self),
              chat.participants.contains(userId) else {
            throw NSError(
                domain: "FirestoreService",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Nemaš dozvolu da obrišeš ovaj razgovor."]
            )
        }

        let messagesSnap = try await chatRef.collection(Constants.Firestore.messages).getDocuments()
        let imageURLs = messagesSnap.documents.compactMap { doc -> String? in
            (try? doc.data(as: Message.self))?.imageURL
        }

        var batch = db.batch()
        var ops = 0
        for doc in messagesSnap.documents {
            batch.deleteDocument(doc.reference)
            ops += 1
            if ops >= 450 {
                try await batch.commit()
                batch = db.batch()
                ops = 0
            }
        }
        batch.deleteDocument(chatRef)
        try await batch.commit()

        await StorageService.shared.deleteDownloadURLs(imageURLs.compactMap { $0 })
    }

    func markChatRead(chatId: String, userId: String) async throws {
        try await db.collection(Constants.Firestore.chats).document(chatId).updateData([
            "unreadCounts.\(userId)": 0
        ])
    }

    func listenChats(
        userId: String,
        onChange: @escaping ([Chat]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(Constants.Firestore.chats)
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                guard let snapshot else {
                    onChange([])
                    return
                }
                let chats: [Chat] = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Chat.self)
                }
                onChange(chats.sorted { $0.lastMessageAt > $1.lastMessageAt })
            }
    }

    func listenMessages(
        chatId: String,
        onChange: @escaping ([Message]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(Constants.Firestore.chats).document(chatId)
            .collection(Constants.Firestore.messages)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                guard let snapshot else {
                    onChange([])
                    return
                }
                let messages: [Message] = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                }
                onChange(messages)
            }
    }

    // MARK: - Korisnici / pretraga / praćenje

    /// Pretraga po imenu (prefiks + lokalni filter za deo reči).
    func searchUsers(matching query: String, excludingUserId: String?) async throws -> [AppUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let col = db.collection(Constants.Firestore.users)
        var results: [AppUser] = []

        let prefixSnap = try await col
            .order(by: "displayName")
            .start(at: [trimmed])
            .end(at: [trimmed + "\u{f8ff}"])
            .limit(to: 30)
            .getDocuments()
        results.append(contentsOf: try prefixSnap.documents.compactMap { try $0.data(as: AppUser.self) })

        if results.count < 12 {
            let broadSnap = try await col.order(by: "displayName").limit(to: 120).getDocuments()
            let broad = try broadSnap.documents.compactMap { try $0.data(as: AppUser.self) }
            let needle = trimmed.lowercased()
            for user in broad where !results.contains(where: { $0.uid == user.uid }) {
                if user.displayName.localizedCaseInsensitiveContains(needle)
                    || user.department.localizedCaseInsensitiveContains(needle) {
                    results.append(user)
                }
                if results.count >= 30 { break }
            }
        }

        if let excludingUserId {
            results.removeAll { $0.uid == excludingUserId }
        }
        return results.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func fetchFollowing(userId: String) async throws -> [UserFollow] {
        let snap = try await db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.following)
            .getDocuments()
        let list = try snap.documents.compactMap { try $0.data(as: UserFollow.self) }
        return list.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func fetchFollowers(userId: String) async throws -> [UserFollower] {
        let snap = try await db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.followers)
            .getDocuments()
        let list = try snap.documents.compactMap { try $0.data(as: UserFollower.self) }
        return list.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func fetchConnectionCounts(userId: String) async throws -> (followers: Int, following: Int) {
        async let followersSnap = db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.followers)
            .getDocuments()
        async let followingSnap = db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.following)
            .getDocuments()
        let (followers, following) = try await (followersSnap, followingSnap)
        return (followers.count, following.count)
    }

    func isFollowing(fromUserId: String, targetUserId: String) async throws -> Bool {
        let doc = try await db.collection(Constants.Firestore.users)
            .document(fromUserId)
            .collection(Constants.Firestore.following)
            .document(targetUserId)
            .getDocument()
        return doc.exists
    }

    func followUser(fromUser: AppUser, target: AppUser) async throws {
        guard fromUser.uid != target.uid else { return }
        let followingRef = db.collection(Constants.Firestore.users)
            .document(fromUser.uid)
            .collection(Constants.Firestore.following)
            .document(target.uid)
        let follow = UserFollow(
            id: target.uid,
            targetUserId: target.uid,
            displayName: target.displayName,
            profileImageURL: target.profileImageURL,
            createdAt: Date()
        )
        try followingRef.setData(from: follow)

        let followersRef = db.collection(Constants.Firestore.users)
            .document(target.uid)
            .collection(Constants.Firestore.followers)
            .document(fromUser.uid)
        let follower = UserFollower(
            id: fromUser.uid,
            followerUserId: fromUser.uid,
            displayName: fromUser.displayName,
            profileImageURL: fromUser.profileImageURL,
            createdAt: Date()
        )
        try followersRef.setData(from: follower)
    }

    func unfollowUser(fromUserId: String, targetUserId: String) async throws {
        try await db.collection(Constants.Firestore.users)
            .document(fromUserId)
            .collection(Constants.Firestore.following)
            .document(targetUserId)
            .delete()
        try await db.collection(Constants.Firestore.users)
            .document(targetUserId)
            .collection(Constants.Firestore.followers)
            .document(fromUserId)
            .delete()
    }

    /// Popunjava `users/{target}/followers/{me}` za sve koje `user` već prati (stari zapisi pre mirror logike).
    /// Vraća broj novo kreiranih dokumenata.
    @discardableResult
    func migrateFollowersMirror(for user: AppUser) async throws -> Int {
        let following = try await fetchFollowing(userId: user.uid)
        guard !following.isEmpty else { return 0 }

        var created = 0
        for entry in following {
            let targetId = entry.targetUserId
            guard targetId != user.uid else { continue }

            let ref = db.collection(Constants.Firestore.users)
                .document(targetId)
                .collection(Constants.Firestore.followers)
                .document(user.uid)

            let existing = try await ref.getDocument()
            if existing.exists { continue }

            let follower = UserFollower(
                id: user.uid,
                followerUserId: user.uid,
                displayName: user.displayName,
                profileImageURL: user.profileImageURL,
                createdAt: entry.createdAt
            )
            try ref.setData(from: follower)
            created += 1
        }
        return created
    }

    /// Ažurira keširano ime i sliku u svim `following` / `followers` zapisima gde se korisnik pojavljuje.
    /// Dokument je uvek `…/following/{userId}` ili `…/followers/{userId}`.
    @discardableResult
    func syncFollowProfileMirrors(
        userId: String,
        displayName: String,
        profileImageURL: String?,
        previousDisplayName: String?,
        previousProfileImageURL: String?
    ) async throws -> Int {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPhoto = profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldPhoto = previousProfileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        let nameChanged = trimmedName != (previousDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        let photoChanged = newPhoto != oldPhoto
        guard nameChanged || photoChanged else { return 0 }

        var patch: [String: Any] = [:]
        if nameChanged {
            patch["displayName"] = trimmedName
        }
        if photoChanged {
            if let newPhoto, !newPhoto.isEmpty {
                patch["profileImageURL"] = newPhoto
            } else {
                patch["profileImageURL"] = FieldValue.delete()
            }
        }

        async let followingSnap = db.collectionGroup(Constants.Firestore.following)
            .whereField("targetUserId", isEqualTo: userId)
            .getDocuments(source: .server)
        async let followersSnap = db.collectionGroup(Constants.Firestore.followers)
            .whereField("followerUserId", isEqualTo: userId)
            .getDocuments(source: .server)

        let documents = try await (followingSnap, followersSnap)
        var seen = Set<String>()
        let refs = (documents.0.documents + documents.1.documents).compactMap { doc -> DocumentReference? in
            let path = doc.reference.path
            guard seen.insert(path).inserted else { return nil }
            return doc.reference
        }
        guard !refs.isEmpty else { return 0 }

        let batchLimit = 500
        var batch = db.batch()
        var opCount = 0
        var updated = 0

        for ref in refs {
            batch.updateData(patch, forDocument: ref)
            opCount += 1
            updated += 1
            if opCount >= batchLimit {
                try await batch.commit()
                batch = db.batch()
                opCount = 0
            }
        }
        if opCount > 0 {
            try await batch.commit()
        }
        return updated
    }

    func listenFollowers(
        userId: String,
        onChange: @escaping ([UserFollower]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.followers)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                let list: [UserFollower] = snapshot?.documents.compactMap {
                    try? $0.data(as: UserFollower.self)
                } ?? []
                onChange(list.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                })
            }
    }

    func listenFollowing(
        userId: String,
        onChange: @escaping ([UserFollow]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.following)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                let list: [UserFollow] = snapshot?.documents.compactMap {
                    try? $0.data(as: UserFollow.self)
                } ?? []
                onChange(list.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                })
            }
    }

    func listenConnectionCounts(
        userId: String,
        onChange: @escaping (_ followers: Int, _ following: Int) -> Void
    ) -> [ListenerRegistration] {
        var followersCount = 0
        var followingCount = 0

        let followersListener = db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.followers)
            .addSnapshotListener { snapshot, _ in
                followersCount = snapshot?.documents.count ?? 0
                onChange(followersCount, followingCount)
            }

        let followingListener = db.collection(Constants.Firestore.users)
            .document(userId)
            .collection(Constants.Firestore.following)
            .addSnapshotListener { snapshot, _ in
                followingCount = snapshot?.documents.count ?? 0
                onChange(followersCount, followingCount)
            }

        return [followersListener, followingListener]
    }
}
