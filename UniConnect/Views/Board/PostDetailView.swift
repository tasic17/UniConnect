import SwiftUI

struct PostDetailView: View {
    let postId: String
    var navigationPath: Binding<NavigationPath>?
    @EnvironmentObject var boardVM: BoardViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var followVM: FollowViewModel
    @EnvironmentObject var authorCache: AuthorProfileCache
    @Environment(\.dismiss) private var dismiss
    @State private var showEditPost = false
    @State private var showReport = false
    @State private var sharePayload: SharedContentPayload?
    @State private var isOpeningChat = false
    /// Učitavanje direktno iz Firestore kada oglas nije u kešu table (npr. neaktivan ili otvoren sa profila).
    @State private var loadedPost: Post?

    private var post: Post? {
        loadedPost ?? boardVM.posts.first { $0.id == postId }
    }

    private var isAuthor: Bool {
        guard let post, let uid = authViewModel.currentUser?.uid else { return false }
        return post.authorId == uid
    }

    var body: some View {
        Group {
            if let post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(post.category.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Constants.Colors.primary.opacity(0.15))
                            .foregroundStyle(Constants.Colors.primary)
                            .clipShape(Capsule())

                        if !post.imageURLs.isEmpty {
                            TabView {
                                ForEach(post.imageURLs, id: \.self) { urlStr in
                                    if let u = URL(string: urlStr) {
                                        AsyncImage(url: u) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .font(.largeTitle)
                                                    .foregroundStyle(.secondary)
                                                    .frame(maxWidth: .infinity, minHeight: 180)
                                            default:
                                                ProgressView()
                                                    .frame(maxWidth: .infinity, minHeight: 180)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .frame(height: 220)
                            .tabViewStyle(.page(indexDisplayMode: .automatic))
                        }

                        labeledBlock(title: "Opis") {
                            Text(post.description.isEmpty ? "—" : post.description)
                                .font(.body)
                        }

                        if let price = post.price {
                            labeledBlock(title: "Cena") {
                                Text(price, format: .currency(code: "RSD"))
                                    .font(.body)
                            }
                        }

                        labeledBlock(title: "Objavio") {
                            AuthorProfileTapRow(
                                userId: post.authorId,
                                fallbackName: post.authorName,
                                navigationPath: navigationPath
                            )
                        }

                        if let dept = post.department, !dept.isEmpty {
                            labeledBlock(title: "Smer / oglas") {
                                Text(dept)
                                    .font(.body)
                            }
                        }

                        labeledBlock(title: "Datum") {
                            Text(post.createdAt.formatted(date: .long, time: .shortened))
                                .font(.body)
                        }

                        if !isAuthor, authViewModel.currentUser != nil {
                            Button {
                                Task { await openMessageThread(post: post) }
                            } label: {
                                if isOpeningChat {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label("Pošalji poruku", systemImage: "message.fill")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Constants.Colors.primary)
                            .disabled(isOpeningChat)
                        }

                        if isAuthor {
                            Button(role: .destructive) {
                                Task {
                                    await boardVM.deletePost(id: postId)
                                    if boardVM.errorMessage == nil {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Obriši oglas")
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        if let err = boardVM.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            } else {
                ProgressView("Učitavanje…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(post?.title ?? "Oglas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if post != nil, authViewModel.currentUser != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            if let p = post, let id = p.id {
                                sharePayload = .post(id: id, title: p.title)
                            }
                        } label: {
                            Label("Pošalji u chat", systemImage: "paperplane")
                        }
                        if isAuthor {
                            Button("Uredi") {
                                boardVM.errorMessage = nil
                                showEditPost = true
                            }
                        } else {
                            Button(role: .destructive) {
                                showReport = true
                            } label: {
                                Label("Prijavi", systemImage: "flag")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            SendContentToChatSheet(payload: payload)
                .environmentObject(authViewModel)
                .environmentObject(chatVM)
                .environmentObject(followVM)
                .environmentObject(authorCache)
        }
        .sheet(isPresented: $showReport) {
            if let p = post, let id = p.id {
                ReportContentView(
                    targetType: .post,
                    targetId: id,
                    targetTitle: p.title
                )
                .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showEditPost) {
            if let p = post {
                EditPostView(post: p)
                    .environmentObject(boardVM)
            }
        }
        .task {
            await boardVM.ensureBoardLoadedIfEmpty()
            if let fromBoard = boardVM.posts.first(where: { $0.id == postId }) {
                loadedPost = fromBoard
            } else if let remote = try? await FirestoreService.shared.fetchPost(id: postId) {
                loadedPost = remote
            } else {
                loadedPost = nil
            }
        }
    }

    private func labeledBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func openMessageThread(post: Post) async {
        guard let uid = authViewModel.currentUser?.uid,
              let postId = post.id else { return }
        isOpeningChat = true
        defer { isOpeningChat = false }
        if let chatId = await chatVM.openChat(
            currentUserId: uid,
            otherUserId: post.authorId,
            postId: postId,
            postTitle: post.title
        ) {
            chatVM.requestOpenChat(chatId: chatId)
        }
    }
}
