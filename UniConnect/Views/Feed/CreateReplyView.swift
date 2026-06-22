import PhotosUI
import SwiftUI
import UIKit

struct CreateReplyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    let parentPost: FeedPost
    let parentPostId: String
    let threadRootId: String

    @State private var content = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var replyPhotoPreviews: [UIImage] = []
    private let maxLength = 2000

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Odgovarate korisniku \(parentPost.authorName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(parentPost.content)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !parentPost.feedImageURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(parentPost.feedImageURLs.enumerated()), id: \.offset) { _, urlStr in
                                    RemoteThumbnailImage(urlString: urlStr, width: 72, height: 72, cornerRadius: 8)
                                }
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                } header: {
                    Text("Tekst odgovora")
                } footer: {
                    Text("\(min(content.count, maxLength))/\(maxLength)")
                        .foregroundStyle(content.count > maxLength ? .red : .secondary)
                }

                Section {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: PhotoImport.maxPostImages,
                        matching: .images
                    ) {
                        Label("Izaberi slike (do \(PhotoImport.maxPostImages))", systemImage: "photo.on.rectangle.angled")
                    }
                    if !replyPhotoPreviews.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(replyPhotoPreviews.enumerated()), id: \.offset) { _, img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    } else if !selectedPhotos.isEmpty {
                        Text("\(selectedPhotos.count) slika izabrano")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Slike")
                } footer: {
                    Text("Opciono. Prikazuju se ispod teksta u thread-u.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Odgovor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pošalji") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || feedViewModel.isLoading)
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task { await rebuildReplyPreviews(from: newItems) }
            }
        }
    }

    private var canSubmit: Bool {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBody = !t.isEmpty || !selectedPhotos.isEmpty
        guard authViewModel.currentUser != nil, hasBody else { return false }
        if !t.isEmpty, t.count > maxLength { return false }
        return true
    }

    private func rebuildReplyPreviews(from items: [PhotosPickerItem]) async {
        let datas = await PhotoImport.jpegDatas(from: items)
        let imgs = datas.compactMap { UIImage(data: $0) }
        await MainActor.run { replyPhotoPreviews = imgs }
    }

    private func submit() async {
        guard let user = authViewModel.currentUser else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmed.count > maxLength ? String(trimmed.prefix(maxLength)) : trimmed
        let datas = await PhotoImport.jpegDatas(from: selectedPhotos)
        guard !text.isEmpty || !datas.isEmpty else { return }
        let ok = await feedViewModel.createReply(
            content: text,
            parentPost: parentPost,
            parentPostId: parentPostId,
            threadRootId: threadRootId,
            authorId: user.uid,
            authorName: user.displayName,
            authorProfileImageURL: user.profileImageURL,
            authorDepartment: user.department,
            imageDatas: datas
        )
        if ok {
            await Task.yield()
            await MainActor.run { dismiss() }
        }
    }
}
