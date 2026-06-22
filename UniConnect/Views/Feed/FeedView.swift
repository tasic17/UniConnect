import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var viewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var showComposer = false
    @State private var filterMyDepartmentOnly = false
    @State private var expandedThreads: Set<String> = []
    @State private var replyTarget: ReplyTarget?

    private var displayedPosts: [FeedPost] {
        let list = viewModel.posts
        guard filterMyDepartmentOnly, let dept = authViewModel.currentUser?.department else {
            return list
        }
        return list.filter { $0.targetDepartment == nil || $0.targetDepartment == dept }
    }

    private var feedRows: [(String, FeedPost)] {
        displayedPosts.compactMap { p in
            guard let id = p.id else { return nil }
            return (id, p)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "Sve", isSelected: !filterMyDepartmentOnly) {
                            filterMyDepartmentOnly = false
                        }
                        FilterChip(title: "Moj smer", isSelected: filterMyDepartmentOnly) {
                            filterMyDepartmentOnly = true
                        }
                    }
                    .padding(.horizontal)
                }

                if viewModel.isLoading && viewModel.posts.isEmpty {
                    Spacer()
                    ProgressView("Učitavanje…")
                    Spacer()
                } else if displayedPosts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(viewModel.posts.isEmpty ? "Nema objava" : "Ništa za ovaj filter")
                            .font(.headline)
                        if viewModel.posts.isEmpty {
                            Text("Podeli prvom objavu sa +.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(feedRows, id: \.0) { row in
                            let rootId = row.0
                            let rootPost = row.1
                            threadBlock(rootId: rootId, rootPost: rootPost)
                                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 1)
                    .scrollContentBackground(.hidden)
                    .background(Constants.Colors.background)
                }
            }
            .background(Constants.Colors.background)
            .navigationTitle("Objave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nova objava")
                }
            }
            .sheet(isPresented: $showComposer) {
                CreateFeedPostView()
                    .environmentObject(viewModel)
                    .environmentObject(authViewModel)
            }
            .sheet(item: $replyTarget) { target in
                CreateReplyView(
                    parentPost: target.parentPost,
                    parentPostId: target.parentPostId,
                    threadRootId: target.threadRootId
                )
                .environmentObject(viewModel)
                .environmentObject(authViewModel)
            }
            .task {
                await viewModel.ensureFeedLoadedIfEmpty()
            }
            .refreshable {
                await viewModel.fetchPosts()
            }
            .alert("Greška", isPresented: errorBinding, actions: {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            }, message: {
                if let msg = viewModel.errorMessage {
                    Text(msg)
                }
            })
            .navigationDestination(for: AuthorProfileNavigationID.self) { target in
                UserProfileView(userId: target.userId)
                    .environmentObject(authViewModel)
            }
        }
    }

    @ViewBuilder
    private func threadBlock(rootId: String, rootPost: FeedPost) -> some View {
        let expanded = expandedThreads.contains(rootId)
        VStack(alignment: .leading, spacing: 6) {
            FeedPostRow(
                post: rootPost,
                postId: rootId,
                threadRootId: rootId,
                indentLevel: 0,
                showThreadToggle: true,
                isThreadExpanded: expanded,
                onToggleThread: { toggleThread(rootId: rootId) },
                onReply: {
                    replyTarget = ReplyTarget(
                        parentPost: rootPost,
                        parentPostId: rootId,
                        threadRootId: rootId
                    )
                },
                onDelete: { Task { await viewModel.deletePost(rootPost) } }
            )

            if expanded {
                if viewModel.loadingThreadIds.contains(rootId) {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if let replies = viewModel.threadReplies[rootId], !replies.isEmpty {
                    let index = threadIndex(root: rootPost, replies: replies)
                    ForEach(replies.compactMap { r -> (String, FeedPost)? in
                        guard let id = r.id else { return nil }
                        return (id, r)
                    }, id: \.0) { pair in
                        let indent = threadIndent(for: pair.1, rootId: rootId, index: index)
                        FeedPostRow(
                            post: pair.1,
                            postId: pair.0,
                            threadRootId: rootId,
                            indentLevel: indent,
                            showThreadToggle: false,
                            isThreadExpanded: false,
                            onToggleThread: nil,
                            onReply: {
                                replyTarget = ReplyTarget(
                                    parentPost: pair.1,
                                    parentPostId: pair.0,
                                    threadRootId: rootId
                                )
                            },
                            onDelete: { Task { await viewModel.deletePost(pair.1) } }
                        )
                    }
                } else {
                    Text("Nema odgovora.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }
        }
    }

    private func toggleThread(rootId: String) {
        if expandedThreads.contains(rootId) {
            expandedThreads.remove(rootId)
        } else {
            expandedThreads.insert(rootId)
            Task { await viewModel.loadThread(rootId: rootId) }
        }
    }

    private func threadIndex(root: FeedPost, replies: [FeedPost]) -> [String: FeedPost] {
        var map: [String: FeedPost] = [:]
        if let id = root.id {
            map[id] = root
        }
        for r in replies {
            if let id = r.id {
                map[id] = r
            }
        }
        return map
    }

    /// Nivo uvlake ispod korena (1 = direktan odgovor na koren, 2 = odgovor na odgovor, …).
    private func threadIndent(for post: FeedPost, rootId: String, index: [String: FeedPost]) -> Int {
        var level = 0
        var parentId = post.parentId
        while let cur = parentId {
            level += 1
            if cur == rootId { break }
            parentId = index[cur]?.parentId
            if level > 40 { break }
        }
        return level
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct ReplyTarget: Identifiable {
    let id = UUID()
    let parentPost: FeedPost
    let parentPostId: String
    let threadRootId: String
}

private struct FeedPostImageStrip: View {
    let urls: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(urls.enumerated()), id: \.offset) { _, urlStr in
                if let u = URL(string: urlStr) {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholder
                        case .empty:
                            ProgressView()
                        @unknown default:
                            placeholder
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var placeholder: some View {
        Color(.systemGray5)
            .frame(maxWidth: .infinity, minHeight: 120)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Mali krug — profilna ili inicijali pored imena u feed-u.
private struct FeedAuthorAvatar: View {
    let imageURL: String?
    let name: String
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
            if let s = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty,
               let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        initialsView
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(width: size, height: size)
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Text(initials(from: name))
            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(Constants.Colors.primary)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    private func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if parts.count >= 2 {
            let a = parts[0].first.map(String.init) ?? ""
            let b = parts[1].first.map(String.init) ?? ""
            return (a + b).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}

private struct FeedPostRow: View {
    let post: FeedPost
    let postId: String
    let threadRootId: String
    var indentLevel: Int = 0
    var showThreadToggle: Bool = false
    var isThreadExpanded: Bool = false
    var onToggleThread: (() -> Void)?
    let onReply: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var viewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    private var isAuthor: Bool {
        authViewModel.currentUser?.uid == post.authorId
    }

    private var isLiked: Bool {
        guard let uid = authViewModel.currentUser?.uid else { return false }
        return post.likes.contains(uid)
    }

    /// Starije objave možda nemaju URL — za sopstvene prikaži aktuelnu sliku; inače keš iz `users`.
    private var resolvedAvatarURL: String? {
        if let u = post.authorProfileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
            return u
        }
        if isAuthor, let me = authViewModel.currentUser?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !me.isEmpty {
            return me
        }
        let cached = viewModel.authorProfileURLCache[post.authorId] ?? ""
        return cached.isEmpty ? nil : cached
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                if indentLevel > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Constants.Colors.primary.opacity(0.25))
                        .frame(width: 3)
                        .padding(.trailing, 10)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 10) {
                        NavigationLink(value: AuthorProfileNavigationID(userId: post.authorId)) {
                            HStack(alignment: .center, spacing: 10) {
                                FeedAuthorAvatar(
                                    imageURL: resolvedAvatarURL,
                                    name: post.authorName,
                                    size: indentLevel > 0 ? 32 : 38
                                )
                                Text(DisplayNameFormat.firstLast(from: post.authorName))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: true)

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 2) {
                            if post.parentId != nil {
                                Text("Odgovor")
                                    .font(.caption2)
                                    .foregroundStyle(Constants.Colors.primary)
                            }
                            Text(post.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.trailing)
                        }
                        .fixedSize(horizontal: true, vertical: true)
                    }

                    if post.isRootPost, let target = post.targetDepartment {
                        Text("Za: \(target)")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Constants.Colors.primary.opacity(0.12))
                            .foregroundStyle(Constants.Colors.primary)
                            .clipShape(Capsule())
                    }

                    if showThreadToggle, post.isRootPost {
                        Button {
                            onToggleThread?()
                        } label: {
                            Text(post.content)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(post.content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !post.feedImageURLs.isEmpty {
                        FeedPostImageStrip(urls: post.feedImageURLs)
                    }

                    HStack(spacing: 16) {
                        Button {
                            guard let uid = authViewModel.currentUser?.uid else { return }
                            Task { await viewModel.toggleLike(postId: postId, userId: uid) }
                        } label: {
                            Label("\(post.likesCount)", systemImage: isLiked ? "heart.fill" : "heart")
                                .font(.subheadline)
                                .foregroundStyle(isLiked ? Color.red : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(authViewModel.currentUser == nil)

                        Button(action: onReply) {
                            Label("Odgovori", systemImage: "arrowshape.turn.up.left")
                                .font(.subheadline)
                                .foregroundStyle(Constants.Colors.primary)
                        }
                        .buttonStyle(.borderless)

                        Spacer(minLength: 0)
                    }

                    if showThreadToggle, post.isRootPost, post.displayReplyCount > 0 {
                        Button {
                            onToggleThread?()
                        } label: {
                            Text(isThreadExpanded
                                 ? "Sakrij odgovore"
                                 : post.displayReplyCount == 1
                                    ? "Prikaži 1 odgovor"
                                    : "Prikaži \(post.displayReplyCount) odgovora")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Constants.Colors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .padding(.leading, CGFloat(indentLevel) * 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
        .contextMenu {
            if isAuthor {
                Button(role: .destructive, action: onDelete) {
                    Label("Obriši", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isAuthor {
                Button(role: .destructive, action: onDelete) {
                    Label("Obriši", systemImage: "trash")
                }
            }
        }
        .task(id: post.authorId) {
            await viewModel.ensureAuthorAvatarLoaded(authorId: post.authorId)
        }
    }
}
