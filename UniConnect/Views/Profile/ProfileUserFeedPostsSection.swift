import SwiftUI

/// Korenje feed objave korisnika na profilu; uredi / obriši samo za vlasnika.
struct ProfileUserFeedPostsSection: View {
    let userId: String
    let isMe: Bool

    @EnvironmentObject private var feedVM: FeedViewModel

    @State private var feedRoots: [FeedPost] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var postToEdit: FeedPostEditSheetItem?
    @State private var postToDelete: FeedPost?
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objave (feed)")
                .font(.headline)

            if isLoading && feedRoots.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if let loadError {
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if feedRoots.isEmpty {
                Text(isMe ? "Još nemaš objava na feed-u." : "Nema objava na feed-u.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                feedPostsList
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: userId) {
            await loadFeedRoots()
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedPostsDidChange)) { _ in
            Task { await loadFeedRoots() }
        }
        .sheet(item: $postToEdit) { item in
            EditFeedPostView(post: item.post)
                .environmentObject(feedVM)
        }
        .confirmationDialog(
            "Obrisati objavu?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Obriši", role: .destructive) {
                if let p = postToDelete {
                    Task { await feedVM.deletePost(p); await loadFeedRoots() }
                }
                postToDelete = nil
            }
            Button("Otkaži", role: .cancel) {
                postToDelete = nil
            }
        } message: {
            Text("Ceo thread (svi odgovori) biće obrisan.")
        }
    }

    @ViewBuilder
    private var feedPostsList: some View {
        let rows: [(String, FeedPost)] = feedRoots.compactMap { p in
            guard let id = p.id else { return nil }
            return (id, p)
        }
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.0) { index, item in
                let post = item.1
                VStack(alignment: .leading, spacing: 0) {
                    ProfileFeedPostRow(post: post)

                    if isMe {
                        HStack(spacing: 16) {
                            Button {
                                guard let id = post.id else { return }
                                postToEdit = FeedPostEditSheetItem(id: id, post: post)
                            } label: {
                                Label("Uredi", systemImage: "pencil")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                postToDelete = post
                                showDeleteConfirm = true
                            } label: {
                                Label("Obriši", systemImage: "trash")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderless)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
    }

    @MainActor
    private func loadFeedRoots() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            feedRoots = try await FirestoreService.shared.fetchRootFeedPostsByAuthor(authorId: userId)
        } catch {
            loadError = error.localizedDescription
            feedRoots = []
        }
    }
}

private struct ProfileFeedPostRow: View {
    let post: FeedPost

    private var displayName: String {
        DisplayNameFormat.firstLast(from: post.authorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text(post.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let target = post.targetDepartment {
                Text("Za: \(target)")
                    .font(.caption2)
                    .foregroundStyle(Constants.Colors.primary)
            }

            Text(post.content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !post.feedImageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(Array(post.feedImageURLs.enumerated()), id: \.offset) { _, urlStr in
                            RemoteThumbnailImage(urlString: urlStr, width: 72, height: 72, cornerRadius: 8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

/// Stabilan `Identifiable` za sheet — izbegava prazan sheet ako se `isPresented` okine pre nego što se veže `FeedPost`.
private struct FeedPostEditSheetItem: Identifiable {
    let id: String
    let post: FeedPost
}

