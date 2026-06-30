import Foundation
import FirebaseFirestore

struct AdminDashboardStats {
    var usersCount: Int
    var postsCount: Int
    var eventsCount: Int
    var feedPostsCount: Int
    var pendingReportsCount: Int
}

struct UserModerationStats {
    var postsCount: Int
    var feedPostsCount: Int
    var reportsAgainstCount: Int
}

final class AdminService {
    static let shared = AdminService()
    private let db = Firestore.firestore()

    // MARK: - Reports (users)

    func submitReport(_ report: Report) async throws {
        try db.collection(Constants.Firestore.reports).addDocument(from: report)
    }

    // MARK: - Reports (admin)

    func fetchReports(limit: Int = 50, pendingOnly: Bool = false) async throws -> [Report] {
        let snap = try await db.collection(Constants.Firestore.reports)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        let all = try snap.documents.compactMap { try $0.data(as: Report.self) }
        if pendingOnly {
            return all.filter { $0.status == .pending }
        }
        return all
    }

    func updateReportStatus(
        reportId: String,
        status: ReportStatus,
        resolvedBy: String
    ) async throws {
        try await db.collection(Constants.Firestore.reports).document(reportId).updateData([
            "status": status.rawValue,
            "resolvedAt": Timestamp(date: Date()),
            "resolvedBy": resolvedBy
        ])
    }

    // MARK: - Admin logs

    func logAction(
        adminId: String,
        action: String,
        targetType: String? = nil,
        targetId: String? = nil,
        details: String? = nil
    ) async throws {
        let entry = AdminLog(
            adminId: adminId,
            action: action,
            targetType: targetType,
            targetId: targetId,
            details: details
        )
        try db.collection(Constants.Firestore.adminLogs).addDocument(from: entry)
    }

    func fetchAdminLogs(limit: Int = 30) async throws -> [AdminLog] {
        let snap = try await db.collection(Constants.Firestore.adminLogs)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: AdminLog.self) }
    }

    // MARK: - Dashboard

    func fetchDashboardStats() async throws -> AdminDashboardStats {
        async let usersCount = collectionCount(Constants.Firestore.users)
        async let postsCount = collectionCount(Constants.Firestore.posts)
        async let eventsCount = collectionCount(Constants.Firestore.events)
        async let feedPostsCount = collectionCount(Constants.Firestore.feedPosts)
        async let pending = db.collection(Constants.Firestore.reports)
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .getDocuments()

        let results = try await (usersCount, postsCount, eventsCount, feedPostsCount, pending)
        let pendingCount = results.4.documents.compactMap { try? $0.data(as: Report.self) }
            .filter { $0.status == .pending }.count
        return AdminDashboardStats(
            usersCount: results.0,
            postsCount: results.1,
            eventsCount: results.2,
            feedPostsCount: results.3,
            pendingReportsCount: pendingCount
        )
    }

    /// Brzo brojanje — ne povlači sve dokumente.
    private func collectionCount(_ path: String) async throws -> Int {
        let snapshot = try await db.collection(path).count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    // MARK: - Users

    func searchAllUsers(matching query: String, limit: Int = 40) async throws -> [AppUser] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.count >= 2 else { return [] }
        let snap = try await db.collection(Constants.Firestore.users)
            .order(by: "displayName")
            .limit(to: 200)
            .getDocuments()
        let users = try snap.documents.compactMap { try $0.data(as: AppUser.self) }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(needle)
                || $0.email.localizedCaseInsensitiveContains(needle)
        }
        .prefix(limit)
        .map { $0 }
    }

    func fetchUserModerationStats(userId: String) async throws -> UserModerationStats {
        async let posts = db.collection(Constants.Firestore.posts)
            .whereField("authorId", isEqualTo: userId).getDocuments()
        async let feed = db.collection(Constants.Firestore.feedPosts)
            .whereField("authorId", isEqualTo: userId).getDocuments()
        async let reports = db.collection(Constants.Firestore.reports)
            .whereField("targetId", isEqualTo: userId)
            .whereField("targetType", isEqualTo: ReportTargetType.user.rawValue)
            .getDocuments()
        let r = try await (posts, feed, reports)
        return UserModerationStats(
            postsCount: r.0.documents.count,
            feedPostsCount: r.1.documents.count,
            reportsAgainstCount: r.2.documents.count
        )
    }

    func banUser(
        userId: String,
        permanent: Bool,
        until: Date?,
        adminId: String
    ) async throws {
        var data: [String: Any] = ["banned": true]
        if permanent {
            data["bannedUntil"] = FieldValue.delete()
        } else if let until {
            data["bannedUntil"] = Timestamp(date: until)
        }
        try await db.collection(Constants.Firestore.users).document(userId).updateData(data)
        try await logAction(
            adminId: adminId,
            action: permanent ? "ban_permanent" : "ban_suspend",
            targetType: "user",
            targetId: userId,
            details: until.map { "do \($0.formatted())" }
        )
    }

    func unbanUser(userId: String, adminId: String) async throws {
        try await db.collection(Constants.Firestore.users).document(userId).updateData([
            "banned": false,
            "bannedUntil": FieldValue.delete()
        ])
        try await logAction(adminId: adminId, action: "unban", targetType: "user", targetId: userId)
    }

    func clearUserProfileImage(userId: String, adminId: String) async throws {
        let doc = try await db.collection(Constants.Firestore.users).document(userId).getDocument()
        let user = try doc.data(as: AppUser.self)
        if let url = user.profileImageURL, !url.isEmpty {
            await StorageService.shared.deleteDownloadURLs([url])
        }
        try await db.collection(Constants.Firestore.users).document(userId).updateData([
            "profileImageURL": FieldValue.delete()
        ])
        try await logAction(adminId: adminId, action: "clear_profile_image", targetType: "user", targetId: userId)
    }

    // MARK: - Content moderation

    func adminDeletePost(id: String, adminId: String) async throws {
        try await FirestoreService.shared.deletePost(id: id)
        try await logAction(adminId: adminId, action: "delete_post", targetType: "post", targetId: id)
    }

    func adminDeleteEvent(id: String, adminId: String) async throws {
        try await FirestoreService.shared.deleteEvent(id: id)
        try await logAction(adminId: adminId, action: "delete_event", targetType: "event", targetId: id)
    }

    func adminDeleteFeedPost(_ post: FeedPost, adminId: String) async throws {
        try await FirestoreService.shared.deleteFeedDocument(post)
        try await logAction(adminId: adminId, action: "delete_feed_post", targetType: "feedPost", targetId: post.id)
    }

    func archiveExpiredEvents(adminId: String) async throws -> Int {
        let snap = try await db.collection(Constants.Firestore.events).getDocuments()
        let now = Date()
        var count = 0
        for doc in snap.documents {
            guard let event = try? doc.data(as: Event.self) else { continue }
            if event.isArchivedEvent { continue }
            if event.date < now {
                try await doc.reference.updateData(["isArchived": true])
                count += 1
            }
        }
        if count > 0 {
            try await logAction(adminId: adminId, action: "archive_expired_events", details: "\(count) događaja")
        }
        return count
    }

    func resolveReportAndDeleteContent(
        report: Report,
        adminId: String
    ) async throws {
        guard let reportId = report.id else { return }
        switch report.targetType {
        case .post:
            try await adminDeletePost(id: report.targetId, adminId: adminId)
        case .event:
            try await adminDeleteEvent(id: report.targetId, adminId: adminId)
        case .feedPost:
            if let post = try await FirestoreService.shared.fetchFeedPost(id: report.targetId) {
                try await adminDeleteFeedPost(post, adminId: adminId)
            }
        case .message:
            if let chatId = report.chatId, let messageId = report.messageId {
                try await db.collection(Constants.Firestore.chats)
                    .document(chatId)
                    .collection(Constants.Firestore.messages)
                    .document(messageId)
                    .delete()
                try await logAction(
                    adminId: adminId,
                    action: "delete_message",
                    targetType: "message",
                    targetId: messageId,
                    details: "chat \(chatId)"
                )
            }
        case .user:
            try await banUser(userId: report.targetId, permanent: true, until: nil, adminId: adminId)
        }
        try await updateReportStatus(reportId: reportId, status: .resolved, resolvedBy: adminId)
    }
}
