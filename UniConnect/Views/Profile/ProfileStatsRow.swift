import SwiftUI

struct ProfileStatsRow: View {
    let userId: String
    let followersCount: Int
    let followingCount: Int

    var body: some View {
        HStack(spacing: 0) {
            NavigationLink(value: ProfileConnectionsNavigationID(userId: userId, kind: .followers)) {
                statColumn(count: followersCount, label: "Pratioci")
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 36)

            NavigationLink(value: ProfileConnectionsNavigationID(userId: userId, kind: .following)) {
                statColumn(count: followingCount, label: "Pratiš")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statColumn(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
