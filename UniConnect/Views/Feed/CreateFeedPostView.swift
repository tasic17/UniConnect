import PhotosUI
import SwiftUI

struct CreateFeedPostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var content = ""
    @State private var selectedAudienceTag = "all"
    @State private var selectedPhotos: [PhotosPickerItem] = []

    private let maxLength = 2000

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
                    Text("Opciono. Prikazuju se ispod teksta. Kompresija pre slanja.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Vidljivost", selection: $selectedAudienceTag) {
                        Text("Svi studenti").tag("all")
                        ForEach(AppUser.Department.allCases, id: \.self) { dept in
                            Text(dept.rawValue).tag(dept.rawValue)
                        }
                    }
                } header: {
                    Text("Za koga je objava")
                } footer: {
                    Text("Ako izabereš smer, objava je posebno označena; „Svi studenti“ je vidljivo svima.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nova objava")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Objavi") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || feedViewModel.isLoading)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard authViewModel.currentUser != nil else { return false }
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBody = !t.isEmpty || !selectedPhotos.isEmpty
        guard hasBody else { return false }
        if !t.isEmpty && t.count > maxLength { return false }
        return true
    }

    private func targetDepartment() -> String? {
        selectedAudienceTag == "all" ? nil : selectedAudienceTag
    }

    private func submit() async {
        guard let user = authViewModel.currentUser else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmed.count > maxLength ? String(trimmed.prefix(maxLength)) : trimmed
        let datas = await PhotoImport.jpegDatas(from: selectedPhotos)
        guard !text.isEmpty || !datas.isEmpty else { return }
        let ok = await feedViewModel.createPost(
            content: text,
            targetDepartment: targetDepartment(),
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
