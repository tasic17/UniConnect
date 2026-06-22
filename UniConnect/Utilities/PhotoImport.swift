import PhotosUI
import SwiftUI
import UIKit

/// Učitavanje fotografija za oglase i profil (kompresija pre Storage-a).
enum PhotoImport {
    nonisolated static let maxPostImages: Int = 5

    /// Učitava i kompresuje JPEG za upload (redosled = redosled izbora).
    nonisolated static func jpegDatas(from items: [PhotosPickerItem], maxCount: Int = 5) async -> [Data] {
        var out: [Data] = []
        let limit = min(maxCount, maxPostImages)
        for item in items.prefix(limit) {
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: raw) else { continue }
            let jpeg = await MainActor.run {
                ImageCompression.dataForUpload(ui)
            }
            guard let jpeg else { continue }
            out.append(jpeg)
        }
        return out
    }

    nonisolated static func jpegData(from item: PhotosPickerItem?) async -> Data? {
        guard let item,
              let raw = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: raw) else { return nil }
        return await MainActor.run {
            ImageCompression.dataForUpload(ui, maxEdge: 1024, jpegQuality: 0.85)
        }
    }
}
