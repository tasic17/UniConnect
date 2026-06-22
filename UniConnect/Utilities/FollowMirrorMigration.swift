import Foundation

/// Jednokratna migracija: za svaki stari `following` zapis kreira odgovarajući `followers` mirror.
enum FollowMirrorMigration {
    private static let version = 1
    private static let defaultsKeyPrefix = "followMirrorMigration_v"

    @MainActor
    static func runIfNeeded(for user: AppUser) async {
        let key = "\(defaultsKeyPrefix)\(version)_\(user.uid)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            let created = try await FirestoreService.shared.migrateFollowersMirror(for: user)
            UserDefaults.standard.set(true, forKey: key)
            if created > 0 {
                print("[FollowMirrorMigration] Kreirano \(created) followers zapisa za \(user.uid).")
                NotificationCenter.default.post(name: .profileConnectionsDidChange, object: nil)
            }
        } catch {
            print("[FollowMirrorMigration] Greška za \(user.uid): \(error.localizedDescription)")
        }
    }
}
