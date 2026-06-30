import SwiftUI

struct FeedPostDetailView: View {
    let postId: String

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var post: FeedPost?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            ProfileAvatarImage(
                                imageURL: post.authorProfileImageURL,
                                name: post.authorName,
                                size: 44
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DisplayNameFormat.firstLast(from: post.authorName))
                                    .font(.headline)
                                Text(post.createdAt.formatted(date: .long, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if post.parentId != nil {
                            Text("Odgovor u thread-u")
                                .font(.caption)
                                .foregroundStyle(Constants.Colors.primary)
                        }

                        if post.isRootPost, let target = post.targetDepartment {
                            Text("Za: \(target)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Constants.Colors.primary.opacity(0.12))
                                .foregroundStyle(Constants.Colors.primary)
                                .clipShape(Capsule())
                        }

                        Text(post.content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !post.feedImageURLs.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(post.feedImageURLs, id: \.self) { urlStr in
                                    if let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFit()
                                            case .failure:
                                                Color(.systemGray5)
                                                    .frame(height: 120)
                                                    .overlay {
                                                        Image(systemName: "photo")
                                                            .foregroundStyle(.secondary)
                                                    }
                                            case .empty:
                                                ProgressView().frame(height: 120)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }

                        LabeledContent("Sviđanja", value: "\(post.likesCount)")
                    }
                    .padding()
                }
            } else if loadFailed {
                ContentUnavailableView("Objava nije pronađena", systemImage: "bubble.left.and.bubble.right")
            } else {
                ProgressView("Učitavanje…")
            }
        }
        .background(Constants.Colors.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: postId) {
            post = try? await FirestoreService.shared.fetchFeedPost(id: postId)
            loadFailed = post == nil
        }
    }

    private var navigationTitle: String {
        guard let post else { return "Objava" }
        let trimmed = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Objava" }
        return String(trimmed.prefix(40))
    }
}
