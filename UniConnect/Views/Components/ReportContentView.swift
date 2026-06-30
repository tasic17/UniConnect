import SwiftUI

struct ReportContentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    let targetType: ReportTargetType
    let targetId: String
    let targetTitle: String
    var chatId: String?
    var messageId: String?
    var messageText: String?
    var messageImageURL: String?
    var messageSenderId: String?

    @State private var reason: ReportReason = .spam
    @State private var details = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Šta prijavljuješ") {
                    LabeledContent("Tip", value: targetType.label)
                    LabeledContent("Naslov", value: targetTitle)
                }

                Section("Razlog") {
                    Picker("Razlog", selection: $reason) {
                        ForEach(ReportReason.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    TextField("Dodatni opis (opciono)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }

                if didSend {
                    Section {
                        Label("Prijava poslata. Hvala!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSending { ProgressView() } else { Text("Pošalji prijavu") }
                            Spacer()
                        }
                    }
                    .disabled(isSending || didSend || authViewModel.currentUser == nil)
                }
            }
            .navigationTitle("Prijavi sadržaj")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zatvori") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        guard let uid = authViewModel.currentUser?.uid else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = Report(
            reporterId: uid,
            targetType: targetType,
            targetId: targetId,
            reason: reason.rawValue,
            details: trimmedDetails.isEmpty ? nil : trimmedDetails,
            targetTitle: targetTitle,
            chatId: chatId,
            messageId: messageId,
            messageText: messageText,
            messageImageURL: messageImageURL,
            messageSenderId: messageSenderId
        )
        do {
            try await AdminService.shared.submitReport(report)
            didSend = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Toolbar dugme za prijavu.
struct ReportToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "flag")
        }
        .accessibilityLabel("Prijavi")
    }
}
