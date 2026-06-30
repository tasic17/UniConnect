import SwiftUI

struct BannedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text("Nalog je blokiran")
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Odjavi se", role: .destructive) {
                authViewModel.logout()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.Colors.background)
    }

    private var message: String {
        if let until = authViewModel.currentUser?.bannedUntil, until > Date() {
            return "Suspendovan si do \(until.formatted(date: .long, time: .shortened)). Za više informacija kontaktiraj administratora."
        }
        return "Pristup platformi ti je onemogućen. Za više informacija kontaktiraj administratora."
    }
}
