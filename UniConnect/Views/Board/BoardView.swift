import SwiftUI

struct BoardView: View {
    @EnvironmentObject var viewModel: BoardViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showCreatePost = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                TextField("Pretraga…", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "Sve", isSelected: viewModel.selectedCategory == nil) {
                            viewModel.selectedCategory = nil
                        }
                        ForEach(Post.PostCategory.allCases, id: \.self) { cat in
                            FilterChip(title: cat.rawValue, isSelected: viewModel.selectedCategory == cat) {
                                viewModel.selectedCategory = cat
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if viewModel.isLoading && viewModel.posts.isEmpty {
                    Spacer()
                    ProgressView("Učitavanje…")
                    Spacer()
                } else if viewModel.filteredPosts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(viewModel.posts.isEmpty ? "Nema oglasa" : "Ništa za ovaj filter")
                            .font(.headline)
                        if viewModel.posts.isEmpty {
                            Text("Dodaj oglas sa +.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filteredPosts) { post in
                            if let id = post.id {
                                PostRowMainContent(post: post)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        navigationPath.append(PostDetailNavigationID(postId: id))
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 1)
                }
            }
            .navigationTitle("Oglasi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreatePost = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Novi oglas")
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
                    .environmentObject(viewModel)
                    .environmentObject(authViewModel)
            }
            .task {
                await viewModel.ensureBoardLoadedIfEmpty()
            }
            .refreshable {
                await viewModel.fetchPosts()
            }
            .navigationDestination(for: PostDetailNavigationID.self) { nav in
                PostDetailView(postId: nav.postId, navigationPath: $navigationPath)
                    .environmentObject(viewModel)
                    .environmentObject(authViewModel)
            }
            .navigationDestination(for: AuthorProfileNavigationID.self) { target in
                UserProfileView(userId: target.userId)
                    .environmentObject(authViewModel)
            }
        }
    }
}

private struct PostRowMainContent: View {
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let first = post.imageURLs.first, let u = URL(string: first) {
                AsyncImage(url: u) { phase in
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
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
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
                    if let price = post.price {
                        Text(price, format: .currency(code: "RSD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
