import SwiftUI

private enum AdminRoute: Hashable {
    case pendingReports
    case resolvedReports
    case report(id: String)
    case manageUser(uid: String)
    case viewPost(id: String)
    case viewEvent(id: String)
    case viewFeedPost(id: String)
}

struct AdminView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var adminVM = AdminViewModel()
    @State private var userSearch = ""

    var body: some View {
        NavigationStack {
            List {
                dashboardSection
                actionsSection
                reportsSection
                usersSection
                logsSection
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MoreMenuBackButton()
                }
            }
            .navigationDestination(for: AdminRoute.self) { route in
                switch route {
                case .pendingReports:
                    AdminReportsListView(
                        title: "Pending prijave",
                        emptyMessage: "Nema prijava na čekanju.",
                        reports: adminVM.pendingReports
                    )
                    .environmentObject(authViewModel)
                    .environmentObject(adminVM)
                case .resolvedReports:
                    AdminReportsListView(
                        title: "Rešene prijave",
                        emptyMessage: "Nema rešenih prijava.",
                        reports: adminVM.resolvedReports
                    )
                    .environmentObject(authViewModel)
                    .environmentObject(adminVM)
                case .report(let id):
                    if let report = adminVM.report(id: id) {
                        AdminReportDetailView(report: report)
                            .environmentObject(authViewModel)
                            .environmentObject(adminVM)
                    } else {
                        ContentUnavailableView("Prijava nije pronađena", systemImage: "exclamationmark.triangle")
                    }
                case .manageUser(let uid):
                    AdminUserDetailLoader(uid: uid)
                        .environmentObject(authViewModel)
                        .environmentObject(adminVM)
                case .viewPost(let id):
                    PostDetailView(postId: id)
                case .viewEvent(let id):
                    EventDetailView(eventId: id)
                case .viewFeedPost(let id):
                    FeedPostDetailView(postId: id)
                        .environmentObject(authViewModel)
                }
            }
            .refreshable { await adminVM.loadDashboard() }
            .task { await adminVM.loadDashboard() }
            .alert("Greška", isPresented: errorBinding) {
                Button("OK", role: .cancel) { adminVM.errorMessage = nil }
            } message: {
                Text(adminVM.errorMessage ?? "")
            }
            .alert("Uspeh", isPresented: successBinding) {
                Button("OK", role: .cancel) { adminVM.successMessage = nil }
            } message: {
                Text(adminVM.successMessage ?? "")
            }
        }
        .background(OverflowTabNavigationBarHidden())
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { adminVM.errorMessage != nil }, set: { if !$0 { adminVM.errorMessage = nil } })
    }

    private var successBinding: Binding<Bool> {
        Binding(get: { adminVM.successMessage != nil }, set: { if !$0 { adminVM.successMessage = nil } })
    }

    @ViewBuilder
    private var dashboardSection: some View {
        Section("Pregled platforme") {
            if let s = adminVM.stats {
                LabeledContent("Korisnici", value: "\(s.usersCount)")
                LabeledContent("Oglasi", value: "\(s.postsCount)")
                LabeledContent("Događaji", value: "\(s.eventsCount)")
                LabeledContent("Feed objave", value: "\(s.feedPostsCount)")
                LabeledContent("Prijave na čekanju", value: "\(s.pendingReportsCount)")
            } else if adminVM.isLoading {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section("Akcije") {
            Button("Arhiviraj istekle događaje") {
                Task {
                    guard let id = authViewModel.currentUser?.uid else { return }
                    await adminVM.archiveExpiredEvents(adminId: id)
                }
            }
            Button("Osveži prijave") {
                Task { await adminVM.loadReports() }
            }
        }
    }

    @ViewBuilder
    private var reportsSection: some View {
        Section("Prijave") {
            NavigationLink(value: AdminRoute.pendingReports) {
                ReportFolderRow(
                    title: "Pending prijave",
                    subtitle: "Na čekanju",
                    count: adminVM.pendingReports.count,
                    systemImage: "clock.badge.exclamationmark",
                    tint: .orange
                )
            }
            NavigationLink(value: AdminRoute.resolvedReports) {
                ReportFolderRow(
                    title: "Rešene prijave",
                    subtitle: "Resolved i odbijene",
                    count: adminVM.resolvedReports.count,
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
            }
        }
    }

    @ViewBuilder
    private var usersSection: some View {
        Section("Korisnici") {
            HStack {
                TextField("Pretraga po imenu ili emailu", text: $userSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Traži") {
                    Task { await adminVM.searchUsers(query: userSearch) }
                }
                .disabled(userSearch.trimmingCharacters(in: .whitespaces).count < 2)
            }
            ForEach(adminVM.userResults, id: \.uid) { user in
                NavigationLink(value: AdminRoute.manageUser(uid: user.uid)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName).font(.headline)
                        Text(user.email).font(.caption).foregroundStyle(.secondary)
                        if user.isBannedNow {
                            Text("BLOKIRAN").font(.caption2).foregroundStyle(.red)
                        }
                        if user.isAdmin {
                            Text("ADMIN").font(.caption2).foregroundStyle(Constants.Colors.primary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var logsSection: some View {
        Section("Admin log") {
            ForEach(adminVM.logs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.action).font(.subheadline.bold())
                    if let d = log.details { Text(d).font(.caption) }
                    Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ReportFolderRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(count)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

private struct AdminReportsListView: View {
    let title: String
    let emptyMessage: String
    let reports: [Report]
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var adminVM: AdminViewModel

    var body: some View {
        List {
            if reports.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reports) { report in
                    if let id = report.id {
                        NavigationLink(value: AdminRoute.report(id: id)) {
                            ReportRow(report: report)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await adminVM.loadReports() }
    }
}

private struct ReportRow: View {
    let report: Report

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(report.targetType.label).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(.systemGray5)).clipShape(Capsule())
                Text(report.status.rawValue).font(.caption2).foregroundStyle(.secondary)
            }
            Text(report.targetTitle ?? report.targetId).font(.headline).lineLimit(1)
            Text(report.reason).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct AdminReportDetailView: View {
    let report: Report
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Prijava") {
                LabeledContent("Tip", value: report.targetType.label)
                LabeledContent("Razlog", value: report.reason)
                LabeledContent("Status", value: report.status.rawValue)
                if let t = report.targetTitle { LabeledContent("Naslov", value: t) }
                if let d = report.details, !d.isEmpty { LabeledContent("Opis", value: d) }
            }
            if report.targetType == .message {
                Section("Prijavljena poruka") {
                    if let sender = report.messageSenderId {
                        LabeledContent("Pošiljalac ID", value: sender)
                    }
                    if let text = report.messageText, !text.isEmpty {
                        Text(text)
                    }
                    if let url = report.messageImageURL, let u = URL(string: url) {
                        AsyncImage(url: u) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFit()
                            }
                        }
                    }
                }
            }
            if let contentLink = reportedContentLink {
                Section("Prijavljeni sadržaj") {
                    NavigationLink(value: contentLink.route) {
                        Label(contentLink.title, systemImage: contentLink.icon)
                    }
                }
            }
            if report.status == .pending {
                Section("Moderacija") {
                    if report.targetType != .user {
                        Button("Ukloni sadržaj i reši", role: .destructive) {
                            Task {
                                guard let id = authViewModel.currentUser?.uid else { return }
                                await adminVM.resolveReport(report, adminId: id)
                                dismiss()
                            }
                        }
                    }
                    Button("Odbaci prijavu") {
                        Task {
                            guard let id = authViewModel.currentUser?.uid else { return }
                            await adminVM.dismissReport(report: report, adminId: id)
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("Detalj prijave")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var reportedContentLink: (route: AdminRoute, title: String, icon: String)? {
        switch report.targetType {
        case .post:
            return (.viewPost(id: report.targetId), "Pogledaj oglas", "doc.text")
        case .event:
            return (.viewEvent(id: report.targetId), "Pogledaj događaj", "calendar")
        case .feedPost:
            return (.viewFeedPost(id: report.targetId), "Pogledaj objavu", "bubble.left.and.bubble.right")
        case .user:
            return (.manageUser(uid: report.targetId), "Upravljaj korisnikom", "person.crop.circle")
        case .message:
            return nil
        }
    }
}

private struct AdminUserDetailLoader: View {
    let uid: String
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var adminVM: AdminViewModel
    @State private var user: AppUser?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let user {
                AdminUserDetailView(user: user)
                    .environmentObject(authViewModel)
                    .environmentObject(adminVM)
            } else if loadFailed {
                ContentUnavailableView("Korisnik nije pronađen", systemImage: "person.crop.circle.badge.questionmark")
            } else {
                ProgressView("Učitavanje…")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: uid) {
            user = try? await AuthService.shared.fetchUser(uid: uid)
            loadFailed = user == nil
        }
    }
}

struct AdminUserDetailView: View {
    let user: AppUser
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var adminVM: AdminViewModel

    var body: some View {
        List {
            Section {
                NavigationLink {
                    UserProfileView(userId: user.uid)
                } label: {
                    Label("Pogledaj nalog", systemImage: "person.crop.circle")
                }
            }
            Section("Profil") {
                LabeledContent("Ime", value: user.displayName)
                LabeledContent("Email", value: user.email)
                LabeledContent("Uloga", value: user.isAdmin ? "Admin" : "Korisnik")
                if user.isBannedNow {
                    Text("Trenutno blokiran").foregroundStyle(.red)
                }
            }
            if let stats = adminVM.selectedUserStats {
                Section("Statistika") {
                    LabeledContent("Oglasi", value: "\(stats.postsCount)")
                    LabeledContent("Feed objave", value: "\(stats.feedPostsCount)")
                    LabeledContent("Prijave protiv", value: "\(stats.reportsAgainstCount)")
                }
            }
            Section("Moderacija") {
                Button("Suspenduj 7 dana", role: .destructive) {
                    Task {
                        guard let id = authViewModel.currentUser?.uid else { return }
                        await adminVM.banUser(userId: user.uid, permanent: false, days: 7, adminId: id)
                    }
                }
                Button("Trajno blokiraj", role: .destructive) {
                    Task {
                        guard let id = authViewModel.currentUser?.uid else { return }
                        await adminVM.banUser(userId: user.uid, permanent: true, days: nil, adminId: id)
                    }
                }
                Button("Ukloni blokadu") {
                    Task {
                        guard let id = authViewModel.currentUser?.uid else { return }
                        await adminVM.unbanUser(userId: user.uid, adminId: id)
                    }
                }
                Button("Ukloni profilnu sliku", role: .destructive) {
                    Task {
                        guard let id = authViewModel.currentUser?.uid else { return }
                        await adminVM.clearProfileImage(userId: user.uid, adminId: id)
                    }
                }
            }
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await adminVM.loadUserStats(user: user) }
    }
}

// MARK: - More tab: sakrij spoljašnji UIKit nav bar (dupla strelica ka „More“)

private struct MoreMenuBackButton: View {
    var body: some View {
        Button(action: popToMoreMenu) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
        }
        .accessibilityLabel("Nazad na More")
    }

    private func popToMoreMenu() {
        guard let tabBar = TabBarFinder.current else { return }
        tabBar.moreNavigationController.popViewController(animated: true)
    }
}

private enum TabBarFinder {
    static var current: UITabBarController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        return findTabBarController(in: root)
    }

    private static func findTabBarController(in controller: UIViewController?) -> UITabBarController? {
        if let tabBar = controller as? UITabBarController { return tabBar }
        for child in controller?.children ?? [] {
            if let tabBar = findTabBarController(in: child) { return tabBar }
        }
        if let presented = controller?.presentedViewController,
           let tabBar = findTabBarController(in: presented) { return tabBar }
        return nil
    }
}

private struct OverflowTabNavigationBarHidden: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> OverflowTabNavigationBarHiddenController {
        OverflowTabNavigationBarHiddenController()
    }

    func updateUIViewController(_ controller: OverflowTabNavigationBarHiddenController, context: Context) {}
}

private final class OverflowTabNavigationBarHiddenController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let nav = navigationController else { return }
        if isMovingFromParent {
            nav.setNavigationBarHidden(false, animated: animated)
        }
    }
}
