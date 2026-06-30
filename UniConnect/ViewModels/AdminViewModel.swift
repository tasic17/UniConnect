import Combine
import Foundation

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var stats: AdminDashboardStats?
    @Published var pendingReports: [Report] = []
    @Published var resolvedReports: [Report] = []
    @Published var logs: [AdminLog] = []
    @Published var userResults: [AppUser] = []
    @Published var selectedUserStats: UserModerationStats?
    @Published var selectedUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func report(id: String) -> Report? {
        pendingReports.first { $0.id == id } ?? resolvedReports.first { $0.id == id }
    }

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let s = AdminService.shared.fetchDashboardStats()
            async let allReports = AdminService.shared.fetchReports(limit: 200, pendingOnly: false)
            async let l = AdminService.shared.fetchAdminLogs(limit: 15)
            stats = try await s
            splitReports(try await allReports)
            logs = try await l
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadReports() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let allReports = AdminService.shared.fetchReports(limit: 200, pendingOnly: false)
            async let s = AdminService.shared.fetchDashboardStats()
            splitReports(try await allReports)
            stats = try await s
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func splitReports(_ all: [Report]) {
        pendingReports = all.filter { $0.status == .pending }
        resolvedReports = all.filter { $0.status == .resolved || $0.status == .dismissed }
    }

    func searchUsers(query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            userResults = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            userResults = try await AdminService.shared.searchAllUsers(matching: q)
        } catch {
            errorMessage = error.localizedDescription
            userResults = []
        }
    }

    func loadUserStats(user: AppUser) async {
        selectedUser = user
        do {
            selectedUserStats = try await AdminService.shared.fetchUserModerationStats(userId: user.uid)
        } catch {
            selectedUserStats = nil
            errorMessage = error.localizedDescription
        }
    }

    func dismissReport(report: Report, adminId: String) async {
        guard let id = report.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await AdminService.shared.updateReportStatus(reportId: id, status: .dismissed, resolvedBy: adminId)
            try await AdminService.shared.logAction(adminId: adminId, action: "dismiss_report", targetType: "report", targetId: id)
            successMessage = "Prijava odbijena."
            await loadReports()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveReport(_ report: Report, adminId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AdminService.shared.resolveReportAndDeleteContent(report: report, adminId: adminId)
            successMessage = "Prijava rešena — sadržaj uklonjen."
            await loadReports()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func banUser(userId: String, permanent: Bool, days: Int?, adminId: String) async {
        isLoading = true
        defer { isLoading = false }
        let until: Date? = permanent ? nil : Calendar.current.date(byAdding: .day, value: days ?? 7, to: Date())
        do {
            try await AdminService.shared.banUser(userId: userId, permanent: permanent, until: until, adminId: adminId)
            successMessage = permanent ? "Korisnik trajno blokiran." : "Korisnik suspendovan."
            if let u = selectedUser, u.uid == userId {
                await loadUserStats(user: u)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unbanUser(userId: String, adminId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AdminService.shared.unbanUser(userId: userId, adminId: adminId)
            successMessage = "Blokada uklonjena."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearProfileImage(userId: String, adminId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AdminService.shared.clearUserProfileImage(userId: userId, adminId: adminId)
            successMessage = "Profilna slika uklonjena."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveExpiredEvents(adminId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let n = try await AdminService.shared.archiveExpiredEvents(adminId: adminId)
            successMessage = n > 0 ? "Arhivirano \(n) događaja." : "Nema isteklih događaja."
            await loadDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
