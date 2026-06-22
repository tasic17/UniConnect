import SwiftUI

/// Prikaz imena u feed-u: prva i poslednja reč punog imena (npr. „Luka Tasić“ umesto celog stringa sa srednjim imenom).
enum DisplayNameFormat {
    static func firstLast(from fullName: String) -> String {
        let parts = fullName.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let first = parts.first else { return fullName.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count >= 2, let last = parts.last else { return String(first) }
        return "\(first) \(last)"
    }
}

/// Vrednost za `NavigationLink(value:)` / `navigationDestination` ka `UserProfileView`.
struct AuthorProfileNavigationID: Hashable {
    let userId: String
}

/// Vrednost za otvaranje detalja oglasa bez ugnježdenog `NavigationLink { }`.
struct PostDetailNavigationID: Hashable {
    let postId: String
}

enum ProfileConnectionKind: String, Hashable {
    case followers
    case following
}

struct ProfileConnectionsNavigationID: Hashable {
    let userId: String
    let kind: ProfileConnectionKind
}

/// Zajednički avatar — URL ili inicijali.
struct ProfileAvatarImage: View {
    let imageURL: String?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let s = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty {
                RemoteThumbnailImage(
                    urlString: s,
                    width: size,
                    height: size,
                    cornerRadius: size / 2
                )
            } else {
                AuthorInitialsCircle(name: name, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Inicijali kada nema URL profilne (oglasi / detalji).
struct AuthorInitialsCircle: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Text(initials(from: name))
            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(Constants.Colors.primary)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: size, height: size)
            .background(Color(.systemGray5))
            .clipShape(Circle())
    }

    private func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if parts.count >= 2 {
            let a = parts[0].first.map(String.init) ?? ""
            let b = parts[1].first.map(String.init) ?? ""
            return (a + b).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

