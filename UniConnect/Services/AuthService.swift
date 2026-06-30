import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

private enum AuthServiceError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Korisnik nije prijavljen."
        }
    }
}

final class AuthService {
    static let shared = AuthService()
    private let db = Firestore.firestore()

    var currentAuthUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    func login(email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func register(email: String, password: String, displayName: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try await result.user.sendEmailVerification(with: emailVerificationActionSettings())
        return result.user
    }

    func createUserDocument(uid: String, displayName: String, email: String, year: Int, department: String) async throws {
        let user = AppUser(
            uid: uid,
            displayName: displayName,
            email: email,
            year: year,
            department: department,
            bio: nil,
            profileImageURL: nil,
            createdAt: Date(),
            role: "user",
            banned: false,
            bannedUntil: nil
        )
        try db.collection(Constants.Firestore.users).document(uid).setData(from: user)
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func reloadAuthUser() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        try await user.reload()
    }

    /// Firestore rules čitaju `email_verified` iz ID tokena — posle verifikacije obavezno osveži token.
    func refreshVerifiedAuthToken() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        try await user.reload()
        guard user.isEmailVerified else { return }
        _ = try await user.getIDToken(forcingRefresh: true)
    }

    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        try await user.sendEmailVerification(with: emailVerificationActionSettings())
    }

    private func emailVerificationActionSettings() -> ActionCodeSettings {
        let settings = ActionCodeSettings()
        let projectID = FirebaseApp.app()?.options.projectID ?? "uniconnect-e2a78"
        settings.url = URL(string: "https://\(projectID).firebaseapp.com")!
        settings.handleCodeInApp = true
        settings.setIOSBundleID(Bundle.main.bundleIdentifier ?? "com.lukatasic.UniConnect")
        return settings
    }

    func logout() throws {
        try Auth.auth().signOut()
    }

    func fetchCurrentUser() async throws -> AppUser? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let doc = try await db.collection(Constants.Firestore.users).document(uid).getDocument()
        return try doc.data(as: AppUser.self)
    }

    /// Javni profil po UID (isti format kao `users/{uid}`) — za feed, oglase i tuđi profil.
    func fetchUser(uid: String) async throws -> AppUser? {
        let doc = try await db.collection(Constants.Firestore.users).document(uid).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: AppUser.self)
    }

    /// Ažurira dokument `users/{uid}` u Firestore-u (izvor istine za UI).
    /// Slika: `newProfileImageURL` postavi novi URL; `shouldClearProfileImage` obriše polje; oba `false`/`nil` = slika se ne dira.
    func updateUserProfile(
        displayName: String,
        year: Int,
        department: String,
        bio: String?,
        newProfileImageURL: String?,
        shouldClearProfileImage: Bool
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthServiceError.notSignedIn }

        var data: [String: Any] = [
            "displayName": displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            "year": year,
            "department": department
        ]
        let trimmedBio = bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedBio.isEmpty {
            data["bio"] = FieldValue.delete()
        } else {
            data["bio"] = trimmedBio
        }
        if shouldClearProfileImage {
            data["profileImageURL"] = FieldValue.delete()
        } else if let url = newProfileImageURL {
            data["profileImageURL"] = url
        }

        try await db.collection(Constants.Firestore.users).document(uid).updateData(data)
    }
}

