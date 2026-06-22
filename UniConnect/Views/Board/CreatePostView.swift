import PhotosUI
import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var boardVM: BoardViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var category = Post.PostCategory.prodaja
    @State private var priceText = ""
    @State private var includePrice = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    private var parsedPrice: Double? {
        let t = priceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let v = Double(t), v >= 0 else { return nil }
        return v
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: PhotoImport.maxPostImages,
                        matching: .images
                    ) {
                        Label("Izaberi slike (do \(PhotoImport.maxPostImages))", systemImage: "photo.on.rectangle.angled")
                    }
                    if !selectedPhotos.isEmpty {
                        Text("\(selectedPhotos.count) slika izabrano")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Slike")
                } footer: {
                    Text("Opciono. Slike se sabijaju pre slanja da uštediš prostor i protok.")
                        .font(.caption)
                }
                Section {
                    Toggle("Unesi cenu", isOn: $includePrice)
                    if includePrice {
                        TextField("Iznos (RSD)", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Cena")
                } footer: {
                    Text("Cena je opciona (npr. prodaja ili usluge). Ostavi isključeno ako nije relevantno.")
                        .font(.caption)
                }
                if let err = boardVM.errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Novi oglas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Objavi") {
                        Task { await save() }
                    }
                    .disabled(!canSave || boardVM.isLoading || authViewModel.currentUser == nil)
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

    private func save() async {
        guard let user = authViewModel.currentUser else { return }
        let price: Double? = includePrice ? parsedPrice : nil
        if includePrice, parsedPrice == nil {
            boardVM.errorMessage = "Unesi ispravan broj za cenu."
            return
        }
        let datas = await PhotoImport.jpegDatas(from: selectedPhotos)
        let ok = await boardVM.createPost(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            price: price,
            department: user.department,
            authorId: user.uid,
            authorName: user.displayName,
            imageDatas: datas
        )
        if ok {
            await Task.yield()
            await MainActor.run { dismiss() }
        }
    }
}
