import SwiftUI

/// Oglasi korisnika na sopstvenom ili tuđem profilu; uredjivanje preko `PostDetailView` (dugme „Uredi“).
struct ProfileUserPostsSection: View {
    let userId: String
    let isMe: Bool

    @EnvironmentObject private var boardVM: BoardViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var authorPosts: [Post] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private var displayedPosts: [Post] {
        if isMe { return authorPosts }
        return authorPosts.filter(\.isActive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Oglasi")
                .font(.headline)

            if isLoading && authorPosts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if let loadError {
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if displayedPosts.isEmpty {
                Text(isMe ? "Još nemaš objavljenih oglasa." : "Nema javnih oglasa.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayedPosts.enumerated()), id: \.element.id) { index, post in
                        if let id = post.id {
                            NavigationLink(value: PostDetailNavigationID(postId: id)) {
                                ProfilePostRow(post: post, showInactiveBadge: isMe && !post.isActive)
                            }
                            .buttonStyle(.plain)
                            if index < displayedPosts.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            if isMe {
                Text("Neaktivni oglasi vidljivi su samo tebi; drugi vide samo aktivne.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: userId) {
            await loadAuthorPosts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostsDidChange)) { _ in
            Task { await loadAuthorPosts() }
        }
    }

    @MainActor
    private func loadAuthorPosts() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            authorPosts = try await FirestoreService.shared.fetchPostsByAuthor(authorId: userId)
        } catch {
            loadError = error.localizedDescription
            authorPosts = []
        }
    }
}

private struct ProfilePostRow: View {
    let post: Post
    var showInactiveBadge: Bool

    private var firstImageURL: URL? {
        guard let s = post.imageURLs.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let u = URL(string: s) else { return nil }
        return u
    }

    var body: some View {
        Group {
            if let url = firstImageURL {
                HStack(alignment: .top, spacing: 10) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color(.systemGray5)
                                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    textColumn
                }
            } else {
                textColumn
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if showInactiveBadge {
                    Text("Neaktivan")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
            Text(post.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text(post.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Constants.Colors.primary.opacity(0.12))
                    .foregroundStyle(Constants.Colors.primary)
                    .clipShape(Capsule())
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
