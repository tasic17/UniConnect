import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isLoggedIn {
                if !authViewModel.isEmailVerified {
                    EmailVerificationView()
                } else if authViewModel.isBanned {
                    BannedView()
                } else {
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
    }
}

