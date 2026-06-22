import PhotosUI
import SwiftUI
import UIKit

private struct EditFeedImageRow: Identifiable, Equatable {
    let id: UUID
    enum Kind: Equatable {
        case remote(String)
        case local(Data)
    }

    var kind: Kind
}

struct EditFeedPostView: View {
    let post: FeedPost
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedVM: FeedViewModel

    @State private var content: String
    @State private var imageRows: [EditFeedImageRow]
    @State private var selectedPhotos: [PhotosPickerItem] = []

    private let maxLength = 2000

    init(post: FeedPost) {
        self.post = post
        let urls = post.feedImageURLs
        _content = State(initialValue: post.content)
        _imageRows = State(
            initialValue: urls.map { EditFeedImageRow(id: UUID(), kind: .remote($0)) }
        )
    }

    private var postId: String { post.id ?? "" }

    private var maxNewSlots: Int {
        max(0, PhotoImport.maxPostImages - imageRows.count)
    }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                } header: {
                    Text("Tekst")
                } footer: {
                    Text("\(min(content.count, maxLength))/\(maxLength)")
                        .foregroundStyle(content.count > maxLength ? .red : .secondary)
                }

                Section {
                    if imageRows.isEmpty {
                        Text("Nema slika")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(imageRows) { row in
                            imageRowView(row)
                        }
                    }
                    if maxNewSlots > 0 {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: maxNewSlots,
                            matching: .images
                        ) {
                            Label("Dodaj slike", systemImage: "photo.on.rectangle.angled")
                        }
                    }
                } header: {
                    Text("Slike")
                } footer: {
                    Text("Maksimalno \(PhotoImport.maxPostImages) slika. Kompresija pre slanja.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Uredi objavu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sačuvaj") {
                        Task { await save() }
                    }
                    .disabled(!canSave || content.count > maxLength || postId.isEmpty || feedVM.isLoading)
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task { await ingestPickedPhotos(newItems) }
            }
        }
    }

    @ViewBuilder
    private func imageRowView(_ row: EditFeedImageRow) -> some View {
        HStack(spacing: 12) {
            Group {
                switch row.kind {
                case .remote(let urlStr):
                    if let u = URL(string: urlStr) {
                        AsyncImage(url: u) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                placeholderThumb
                            }
                        }
                    } else {
                        placeholderThumb
                    }
                case .local(let data):
                    if let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholderThumb
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                switch row.kind {
                case .remote:
                    Text("Sa servera")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .local:
                    Text("Nova")
                        .font(.caption)
                        .foregroundStyle(Constants.Colors.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                imageRows.removeAll { $0.id == row.id }
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.red, .secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var placeholderThumb: some View {
        Color(.systemGray5)
            .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
    }

    private func ingestPickedPhotos(_ newItems: [PhotosPickerItem]) async {
        let slots = PhotoImport.maxPostImages - imageRows.count
        guard slots > 0 else {
            await MainActor.run { selectedPhotos = [] }
            return
        }
        let take = Array(newItems.prefix(slots))
        let datas = await PhotoImport.jpegDatas(from: take, maxCount: slots)
        await MainActor.run {
            for data in datas {
                imageRows.append(EditFeedImageRow(id: UUID(), kind: .local(data)))
            }
            selectedPhotos = []
        }
    }

    private func imagesMatchPostUnchanged(_ rows: [EditFeedImageRow]) -> Bool {
        let existing = post.feedImageURLs
        guard rows.count == existing.count else { return false }
        for (i, row) in rows.enumerated() {
            if case .remote(let u) = row.kind, i < existing.count, u == existing[i] {
                continue
            }
            return false
        }
        return true
    }

    private func save() async {
        let text = String(content.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        let imageUpdate: FeedPostImageUpdate
        if imageRows.isEmpty {
            imageUpdate = post.feedImageURLs.isEmpty ? .unchanged : .removeAll
        } else if imagesMatchPostUnchanged(imageRows) {
            imageUpdate = .unchanged
        } else {
            let parts: [FeedPostImageOrderedPart] = imageRows.map { row in
                switch row.kind {
                case .remote(let u): return .keepURL(u)
                case .local(let data): return .newUpload(data)
                }
            }
            imageUpdate = .modifyOrdered(parts)
        }

        let ok = await feedVM.updateFeedPost(id: postId, content: text, imageUpdate: imageUpdate)
        if ok {
            await Task.yield()
            await MainActor.run { dismiss() }
        }
    }
}
