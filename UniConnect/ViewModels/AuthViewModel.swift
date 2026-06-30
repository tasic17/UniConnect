import Combine
import Foundation
import FirebaseAuth

final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isEmailVerified = false
    @Published var verificationEmail: String?
    @Published var currentUser: AppUser?
    @Published var isBanned = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.applyAuthUser(user)
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var isAdmin: Bool { currentUser?.isAdmin == true }

    @MainActor
    private func applyAuthUser(_ user: FirebaseAuth.User?) async {
        isLoggedIn = user != nil
        verificationEmail = user?.email
        isEmailVerified = user?.isEmailVerified ?? false
        if user?.isEmailVerified == true {
            try? await AuthService.shared.refreshVerifiedAuthToken()
            isEmailVerified = AuthService.shared.currentAuthUser?.isEmailVerified ?? false
            if isEmailVerified {
                await fetchCurrentUser()
                if currentUser?.isBannedNow == true {
                    isBanned = true
                } else {
                    isBanned = false
                }
            }
        } else {
            currentUser = nil
            isBanned = false
        }
    }

    @MainActor
    func refreshEmailVerificationStatus() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthService.shared.reloadAuthUser()
            try await AuthService.shared.refreshVerifiedAuthToken()
            await applyAuthUser(AuthService.shared.currentAuthUser)
            return isEmailVerified
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// `nil` = uspeh; inače poruka greške.
    @MainActor
    func resendVerificationEmail() async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthService.shared.sendEmailVerification()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await AuthService.shared.login(email: email, password: password)
            await applyAuthUser(AuthService.shared.currentAuthUser)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func register(email: String, password: String, displayName: String, year: Int, department: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let user = try await AuthService.shared.register(email: email, password: password, displayName: displayName)
            try await AuthService.shared.createUserDocument(uid: user.uid, displayName: displayName, email: email, year: year, department: department)
            await applyAuthUser(AuthService.shared.currentAuthUser)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// `nil` = uspeh; inače poruka greške za prikaz na ekranu reset lozinke.
    @MainActor
    func resetPassword(email: String) async -> String? {
        do {
            try await AuthService.shared.resetPassword(email: email)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    func logout() {
        do {
            try AuthService.shared.logout()
            currentUser = nil
            isEmailVerified = false
            verificationEmail = nil
            isBanned = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func fetchCurrentUser() async {
        do {
            currentUser = try await AuthService.shared.fetchCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateProfile(
        displayName: String,
        year: Int,
        department: String,
        bio: String?,
        profileImageData: Data?,
        removeProfileImage: Bool
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let uid = currentUser?.uid else { return false }
            let previousName = currentUser?.displayName
            let previousPhotoURL = currentUser?.profileImageURL
            let oldPhotoURL = previousPhotoURL

            if let data = profileImageData {
                if let old = oldPhotoURL, !old.isEmpty {
                    await StorageService.shared.deleteDownloadURLs([old])
                }
                let url = try await StorageService.shared.uploadProfileImage(uid: uid, data: data)
                try await AuthService.shared.updateUserProfile(
                    displayName: displayName,
                    year: year,
                    department: department,
                    bio: bio,
                    newProfileImageURL: url,
                    shouldClearProfileImage: false
                )
            } else if removeProfileImage {
                if let old = oldPhotoURL, !old.isEmpty {
                    await StorageService.shared.deleteDownloadURLs([old])
                }
                try await AuthService.shared.updateUserProfile(
                    displayName: displayName,
                    year: year,
                    department: department,
                    bio: bio,
                    newProfileImageURL: nil,
                    shouldClearProfileImage: true
                )
            } else {
                try await AuthService.shared.updateUserProfile(
                    displayName: displayName,
                    year: year,
                    department: department,
                    bio: bio,
                    newProfileImageURL: nil,
                    shouldClearProfileImage: false
                )
            }
            await fetchCurrentUser()
            if let user = currentUser {
                do {
                    let mirrorCount = try await FirestoreService.shared.syncFollowProfileMirrors(
                        userId: user.uid,
                        displayName: user.displayName,
                        profileImageURL: user.profileImageURL,
                        previousDisplayName: previousName,
                        previousProfileImageURL: previousPhotoURL
                    )
                    #if DEBUG
                    print("[FollowProfileSync] Ažurirano \(mirrorCount) follow zapisa za \(user.uid).")
                    #endif
                } catch {
                    #if DEBUG
                    print("[FollowProfileSync] Greška: \(error.localizedDescription)")
                    #endif
                }
                NotificationCenter.default.post(name: .userProfileDidUpdate, object: user.uid)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

