import Combine
import Foundation
import FirebaseAuth

final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = user != nil
            if user != nil {
                Task { await self?.fetchCurrentUser() }
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    @MainActor
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await AuthService.shared.login(email: email, password: password)
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func logout() {
        do {
            try AuthService.shared.logout()
            currentUser = nil
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
    func updateProfile(displayName: String, year: Int, department: String, bio: String?) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AuthService.shared.updateUserProfile(
                displayName: displayName,
                year: year,
                department: department,
                bio: bio
            )
            await fetchCurrentUser()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

