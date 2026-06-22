import SwiftUI
import UIKit

/// Mala slika sa URL-a (Firebase Storage); pouzdanije od `AsyncImage` u formama i horizontalnim scroll-ovima.
struct RemoteThumbnailImage: View {
    let urlString: String
    var width: CGFloat = 72
    var height: CGFloat = 72
    var cornerRadius: CGFloat = 8

    @State private var uiImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                Color(.systemGray5)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            } else {
                Color(.systemGray5)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: urlString) {
            await load()
        }
    }

    private func load() async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            await MainActor.run { loadFailed = true }
            return
        }
        await MainActor.run {
            uiImage = nil
            loadFailed = false
        }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                await MainActor.run { loadFailed = true }
                return
            }
            guard let img = UIImage(data: data) else {
                await MainActor.run { loadFailed = true }
                return
            }
            await MainActor.run { uiImage = img }
        } catch {
            await MainActor.run { loadFailed = true }
        }
    }
}
