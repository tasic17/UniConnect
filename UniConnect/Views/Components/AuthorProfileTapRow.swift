import SwiftUI

/// Avatar + ime autora; vodi na profil (dugme + path ili NavigationLink).
struct AuthorProfileTapRow: View {
    let userId: String
    let fallbackName: String
    var navigationPath: Binding<NavigationPath>?
    var avatarSize: CGFloat = 28

    @EnvironmentObject private var authorCache: AuthorProfileCache

    private var displayName: String {
        authorCache.resolvedName(for: userId, fallback: fallbackName)
    }

    var body: some View {
        Group {
            if let navigationPath {
                Button {
                    navigationPath.wrappedValue.append(AuthorProfileNavigationID(userId: userId))
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: AuthorProfileNavigationID(userId: userId)) {
                    rowContent
                }
                .buttonStyle(.plain)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .task(id: userId) {
            await authorCache.ensureLoaded(authorId: userId)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            ProfileAvatarImage(
                imageURL: authorCache.photoURL(for: userId),
                name: displayName,
                size: avatarSize
            )
            Text(displayName)
                .font(.body)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// Red liste (Pratioci / Pratiš) sa uvek svežim imenom i slikom iz `users/{uid}`.
struct LiveProfileConnectionRow: View {
    let userId: String
    let fallbackName: String
    var fallbackPhotoURL: String? = nil

    @EnvironmentObject private var authorCache: AuthorProfileCache

    private var name: String {
        authorCache.resolvedName(for: userId, fallback: fallbackName)
    }

    private var photoURL: String? {
        authorCache.photoURL(for: userId) ?? fallbackPhotoURL
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarImage(imageURL: photoURL, name: name, size: 44)
            Text(DisplayNameFormat.firstLast(from: name))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .task(id: userId) {
            await authorCache.refresh(authorId: userId)
        }
    }
}
