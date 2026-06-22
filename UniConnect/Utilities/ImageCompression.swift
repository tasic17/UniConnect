import UIKit

/// Kompresija i smanjenje rezolucije pre slanja na Storage (manji račun, brži prikaz).
enum ImageCompression {
    /// Glavna slika za detalj / fullscreen — tipično do ~1920 px po dužoj strani, JPEG ~80–85%.
    static func dataForUpload(
        _ image: UIImage,
        maxEdge: CGFloat = 1920,
        jpegQuality: CGFloat = 0.82
    ) -> Data? {
        image.scaledToMaxEdge(maxEdge).jpegData(compressionQuality: jpegQuality)
    }

    /// Manji pregled za liste / ćelije — poseban upload (drugi path), da lista ne vuče velike fajlove.
    static func dataForThumbnail(
        _ image: UIImage,
        maxEdge: CGFloat = 400,
        jpegQuality: CGFloat = 0.76
    ) -> Data? {
        image.scaledToMaxEdge(maxEdge).jpegData(compressionQuality: jpegQuality)
    }
}

private extension UIImage {
    /// Razmera ostaje ista; skalira tako da duža strana bude najviše `maxEdge` tačaka.
    func scaledToMaxEdge(_ maxEdge: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        let maxSide = max(w, h)
        guard maxSide > maxEdge, maxSide > 0 else { return self }

        let scale = maxEdge / maxSide
        let newSize = CGSize(width: (w * scale).rounded(.down), height: (h * scale).rounded(.down))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
