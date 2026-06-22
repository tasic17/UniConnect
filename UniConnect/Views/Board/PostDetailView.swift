import SwiftUI

struct PostDetailView: View {
    let postId: String
    @EnvironmentObject var boardVM: BoardViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditPost = false
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
                            NavigationLink(value: AuthorProfileNavigationID(userId: post.authorId)) {
                                HStack(spacing: 8) {
                                    AuthorInitialsCircle(name: post.authorName, size: 28)
                                    Text(post.authorName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .fixedSize(horizontal: true, vertical: true)
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
            if isAuthor, post != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Uredi") {
                        boardVM.errorMessage = nil
                        showEditPost = true
                    }
                }
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
}
