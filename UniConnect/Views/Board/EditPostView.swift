import PhotosUI
import SwiftUI
import UIKit

private struct EditPostImageRow: Identifiable, Equatable {
    let id: UUID
    enum Kind: Equatable {
        case remote(String)
        case local(Data)
    }

    var kind: Kind
}

struct EditPostView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var boardVM: BoardViewModel

    @State private var title: String
    @State private var descriptionText: String
    @State private var category: Post.PostCategory
    @State private var priceText: String
    @State private var includePrice: Bool
    /// Postojeće (URL) + nove (lokalni JPEG odmah u preview-u); redosled = redosled u oglasu.
    @State private var imageRows: [EditPostImageRow]
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(post: Post) {
        self.post = post
        _title = State(initialValue: post.title)
        _descriptionText = State(initialValue: post.description)
        _category = State(initialValue: post.category)
        _imageRows = State(
            initialValue: post.imageURLs.map { EditPostImageRow(id: UUID(), kind: .remote($0)) }
        )
        if let p = post.price {
            _includePrice = State(initialValue: true)
            _priceText = State(initialValue: Self.formatPrice(p))
        } else {
            _includePrice = State(initialValue: false)
            _priceText = State(initialValue: "")
        }
    }

    private static func formatPrice(_ p: Double) -> String {
        if p.rounded() == p { return "\(Int(p))" }
        return "\(p)"
    }

    private var parsedPrice: Double? {
        let t = priceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let v = Double(t), v >= 0 else { return nil }
        return v
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var postId: String { post.id ?? "" }

    private var maxNewSlots: Int {
        max(0, PhotoImport.maxPostImages - imageRows.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Osnovno") {
                    TextField("Naslov", text: $title)
                    Picker("Kategorija", selection: $category) {
                        ForEach(Post.PostCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }
                Section("Opis") {
                    TextField("Opis oglasa", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...10)
                }
                Section {
                    if imageRows.isEmpty {
                        Text("Još nema slika")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(imageRows.enumerated()), id: \.element.id) { index, row in
                                imageRowView(row: row, index: index)
                                if index < imageRows.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        if imageRows.count > 1 {
                            Text("Koristi strelice ↑ ↓ za redosled u oglasu.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }

                    if maxNewSlots > 0 {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: maxNewSlots,
                            matching: .images
                        ) {
                            Label("Dodaj slike", systemImage: "photo.badge.plus")
                        }
                        .onChange(of: selectedPhotos) { _, newItems in
                            guard !newItems.isEmpty else { return }
                            Task { await ingestPickedPhotos(newItems) }
                        }
                    } else if !imageRows.isEmpty {
                        Text("Maksimalno \(PhotoImport.maxPostImages) slika — obriši neku da dodaš novu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Ukloni sve slike", role: .destructive) {
                        imageRows = []
                        selectedPhotos = []
                    }
                    .disabled(imageRows.isEmpty)
                } header: {
                    Text("Slike")
                }
                Section {
                    Toggle("Unesi cenu", isOn: $includePrice)
                    if includePrice {
                        TextField("Iznos (RSD)", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Cena")
                }
                if let err = boardVM.errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Uredi oglas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sačuvaj") {
                        Task { await save() }
                    }
                    .disabled(!canSave || boardVM.isLoading || postId.isEmpty)
                }
            }
            .overlay {
                if boardVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    @ViewBuilder
    private func imageRowView(row: EditPostImageRow, index: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if imageRows.count > 1 {
                VStack(spacing: 2) {
                    Button {
                        moveRowUp(id: row.id)
                    } label: {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.body)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Constants.Colors.primary, Color(.systemGray5))
                    }
                    .buttonStyle(.borderless)
                    .disabled(index == 0)

                    Button {
                        moveRowDown(id: row.id)
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.body)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Constants.Colors.primary, Color(.systemGray5))
                    }
                    .buttonStyle(.borderless)
                    .disabled(index >= imageRows.count - 1)
                }
                .frame(width: 28)
            }

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
                            case .failure:
                                placeholderThumb
                            default:
                                ProgressView()
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
                    Text("Nova (upload pri čuvanju)")
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

    private func moveRowUp(id: UUID) {
        guard let i = imageRows.firstIndex(where: { $0.id == id }), i > 0 else { return }
        imageRows.swapAt(i, i - 1)
    }

    private func moveRowDown(id: UUID) {
        guard let i = imageRows.firstIndex(where: { $0.id == id }), i < imageRows.count - 1 else { return }
        imageRows.swapAt(i, i + 1)
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
                imageRows.append(EditPostImageRow(id: UUID(), kind: .local(data)))
            }
            selectedPhotos = []
        }
    }

    private func imagesMatchPostUnchanged(_ rows: [EditPostImageRow]) -> Bool {
        guard rows.count == post.imageURLs.count else { return false }
        for (i, row) in rows.enumerated() {
            if case .remote(let u) = row.kind, i < post.imageURLs.count, u == post.imageURLs[i] {
                continue
            }
            return false
        }
        return true
    }

    private func save() async {
        let price: Double? = includePrice ? parsedPrice : nil
        if includePrice, parsedPrice == nil {
            boardVM.errorMessage = "Unesi ispravan broj za cenu."
            return
        }

        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        let imageUpdate: PostImageUpdate
        if imageRows.isEmpty {
            imageUpdate = post.imageURLs.isEmpty ? .unchanged : .removeAll
        } else if imagesMatchPostUnchanged(imageRows) {
            imageUpdate = .unchanged
        } else {
            let parts: [PostImageOrderedPart] = imageRows.map { row in
                switch row.kind {
                case .remote(let u): return .keepURL(u)
                case .local(let data): return .newUpload(data)
                }
            }
            imageUpdate = .modifyOrdered(parts)
        }

        let ok = await boardVM.updatePost(
            id: postId,
            title: t,
            description: d,
            category: category,
            price: price,
            imageUpdate: imageUpdate
        )
        if ok {
            await Task.yield()
            await MainActor.run { dismiss() }
        }
    }
}
