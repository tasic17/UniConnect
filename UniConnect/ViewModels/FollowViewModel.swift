import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class FollowViewModel: ObservableObject {
    @Published private(set) var followingIds: Set<String> = []
    @Published private(set) var followingUsers: [UserFollow] = []
    @Published private(set) var followersCount = 0
    @Published private(set) var followingCount = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var loadedForUserId: String?
    private var countListeners: [ListenerRegistration] = []

    func isFollowing(_ targetUserId: String) -> Bool {
        followingIds.contains(targetUserId)
    }

    func ensureFollowingLoaded(userId: String) async {
        guard loadedForUserId != userId else { return }
        await reloadFollowing(userId: userId)
    }

    func reloadFollowing(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await FirestoreService.shared.fetchFollowing(userId: userId)
            followingUsers = list
            followingIds = Set(list.map(\.targetUserId))
            followingCount = list.count
            loadedForUserId = userId
        } catch {
            errorMessage = error.localizedDescription
            followingUsers = []
            followingIds = []
        }
    }

    func startWatchingCounts(for userId: String?) {
        countListeners.forEach { $0.remove() }
        countListeners = []
        followersCount = 0
        followingCount = 0
        guard let userId else { return }

        countListeners = FirestoreService.shared.listenConnectionCounts(userId: userId) { [weak self] followers, following in
            Task { @MainActor in
                self?.followersCount = followers
                self?.followingCount = following
            }
        }
    }

    func follow(currentUser: AppUser, target: AppUser) async -> Bool {
        errorMessage = nil
        do {
            try await FirestoreService.shared.followUser(fromUser: currentUser, target: target)
            let entry = UserFollow(
                targetUserId: target.uid,
                displayName: target.displayName,
                profileImageURL: target.profileImageURL
            )
            followingUsers.insert(entry, at: 0)
            followingIds.insert(target.uid)
            followingCount = followingUsers.count
            loadedForUserId = currentUser.uid
            NotificationCenter.default.post(name: .profileConnectionsDidChange, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func unfollow(currentUserId: String, targetUserId: String) async -> Bool {
        errorMessage = nil
        do {
            try await FirestoreService.shared.unfollowUser(fromUserId: currentUserId, targetUserId: targetUserId)
            followingIds.remove(targetUserId)
            followingUsers.removeAll { $0.targetUserId == targetUserId }
            followingCount = followingUsers.count
            NotificationCenter.default.post(name: .profileConnectionsDidChange, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

extension Notification.Name {
    static let profileConnectionsDidChange = Notification.Name("UniConnect.profileConnectionsDidChange")
}
