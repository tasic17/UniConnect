import SwiftUI

struct SharedContentCardView: View {
    let payload: SharedContentPayload
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: payload.type.systemImage)
                .font(compact ? .title3 : .title2)
                .foregroundStyle(Constants.Colors.primary)
                .frame(width: compact ? 32 : 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(payload.type.label)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                Text(payload.title)
                    .font(compact ? .subheadline.weight(.medium) : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(compact ? 2 : 3)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            if compact {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Constants.Colors.primary.opacity(0.2), lineWidth: 1)
        }
    }
}

struct SendContentToChatSheet: View {
    let payload: SharedContentPayload

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var followVM: FollowViewModel
    @EnvironmentObject private var authorCache: AuthorProfileCache

    @State private var comment = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Šalješ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    SharedContentCardView(payload: payload)

                    TextField("Komentar (opciono)", text: $comment, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()

                Divider()

                UserSearchView(mode: .pickUserForShare, embeddedInSheet: true) { userId in
                    Task { await send(to: userId) }
                }
                .environmentObject(authViewModel)
                .environmentObject(followVM)
                .environmentObject(authorCache)
            }
            .background(Constants.Colors.background)
            .navigationTitle("Pošalji u chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                        .disabled(isSending)
                }
            }
            .overlay {
                if isSending {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView("Slanje…")
                            .padding(20)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func send(to userId: String) async {
        guard let uid = authViewModel.currentUser?.uid else { return }
        isSending = true
        defer { isSending = false }
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        if let chatId = await chatVM.sendSharedContent(
            currentUserId: uid,
            recipientId: userId,
            type: payload.type,
            contentId: payload.contentId,
            title: payload.title,
            comment: trimmedComment.isEmpty ? nil : trimmedComment
        ) {
            chatVM.requestOpenChat(chatId: chatId)
            dismiss()
        }
    }
}
