import Foundation
import FirebaseAuth
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

    func login(email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func register(email: String, password: String, displayName: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try await result.user.sendEmailVerification()
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
            createdAt: Date()
        )
        try db.collection(Constants.Firestore.users).document(uid).setData(from: user)
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func logout() throws {
        try Auth.auth().signOut()
    }

    func fetchCurrentUser() async throws -> AppUser? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let doc = try await db.collection(Constants.Firestore.users).document(uid).getDocument()
        return try doc.data(as: AppUser.self)
    }

    /// Ažurira dokument `users/{uid}` u Firestore-u (izvor istine za UI).
    func updateUserProfile(displayName: String, year: Int, department: String, bio: String?) async throws {
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

        try await db.collection(Constants.Firestore.users).document(uid).updateData(data)
    }
}

