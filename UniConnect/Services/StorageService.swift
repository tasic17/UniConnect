import FirebaseStorage
import Foundation

/// Upload i brisanje fajlova u Firebase Storage (`profile_images/`, `posts/{id}/`, `feed_posts/{id}/`).
final class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()

    func uploadProfileImage(uid: String, data: Data) async throws -> String {
        let ref = storage.reference().child("profile_images/\(uid).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        return try await ref.downloadURL().absoluteString
    }

    func uploadPostImage(postId: String, index: Int, data: Data) async throws -> String {
        let ref = storage.reference().child("posts/\(postId)/\(index).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        return try await ref.downloadURL().absoluteString
    }

    /// Redom upload (indeks 0,1,2…) — vraća URL-ove u istom redosledu.
    func uploadPostImages(postId: String, datas: [Data]) async throws -> [String] {
        var urls: [String] = []
        for (i, data) in datas.enumerated() {
            urls.append(try await uploadPostImage(postId: postId, index: i, data: data))
        }
        return urls
    }

    /// Jedna nova slika pri uređivanju oglasa (jedinstveno ime).
    func uploadPostImageUnique(postId: String, data: Data) async throws -> String {
        let name = "u_\(UUID().uuidString).jpg"
        let ref = storage.reference().child("posts/\(postId)/\(name)")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        return try await ref.downloadURL().absoluteString
    }

    func uploadFeedPostImage(feedPostId: String, index: Int, data: Data) async throws -> String {
        let ref = storage.reference().child("feed_posts/\(feedPostId)/\(index).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        return try await ref.downloadURL().absoluteString
    }

    func uploadFeedPostImages(feedPostId: String, datas: [Data]) async throws -> [String] {
        var urls: [String] = []
        for (i, data) in datas.enumerated() {
            urls.append(try await uploadFeedPostImage(feedPostId: feedPostId, index: i, data: data))
        }
        return urls
    }

    /// Nova slika pri uređivanju objave (jedinstveno ime u istom folderu kao post).
    func uploadFeedPostImageUnique(feedPostId: String, data: Data) async throws -> String {
        let name = "u_\(UUID().uuidString).jpg"
        let ref = storage.reference().child("feed_posts/\(feedPostId)/\(name)")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        return try await ref.downloadURL().absoluteString
    }

    /// Više novih slika odjednom.
    func uploadPostImagesUnique(postId: String, datas: [Data]) async throws -> [String] {
        var urls: [String] = []
        for data in datas {
            urls.append(try await uploadPostImageUnique(postId: postId, data: data))
        }
        return urls
    }

    func deleteDownloadURLs(_ urls: [String]) async {
        for url in urls {
            guard !url.isEmpty else { continue }
            do {
                let ref = storage.reference(forURL: url)
                try await ref.delete()
            } catch {
                // Stari URL ili već obrisan fajl — ignoriši
            }
        }
    }
}
