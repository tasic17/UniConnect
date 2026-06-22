import Combine
import Foundation
import FirebaseAuth

final class EventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: Event.EventCategory?

    var filteredEvents: [Event] {
        guard let category = selectedCategory else { return events }
        return events.filter { $0.category == category }
    }

    /// Izbegava dupli fetch kad su događaji već učitani u pozadini (`MainTabView`).
    @MainActor
    func ensureEventsLoadedIfEmpty() async {
        guard events.isEmpty else { return }
        await fetchEvents()
    }

    @MainActor
    func fetchEvents() async {
        isLoading = true
        errorMessage = nil
        do {
            var list = try await FirestoreService.shared.fetchEvents()
            if let uid = Auth.auth().currentUser?.uid {
                list = list.map { e in
                    var copy = e
                    copy.isAttending = e.attendees.contains(uid)
                    return copy
                }
            }
            events = list
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func createEvent(
        title: String,
        description: String,
        category: Event.EventCategory,
        date: Date,
        location: String,
        latitude: Double?,
        longitude: Double?,
        authorId: String,
        authorName: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let event = Event(
            title: title,
            description: description,
            category: category,
            authorId: authorId,
            authorName: authorName,
            date: date,
            location: location,
            latitude: latitude,
            longitude: longitude,
            attendeesCount: 0,
            attendees: [],
            createdAt: Date()
        )
        do {
            try await FirestoreService.shared.createEvent(event)
            await fetchEvents()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func updateEvent(
        id: String,
        title: String,
        description: String,
        category: Event.EventCategory,
        date: Date,
        location: String,
        latitude: Double?,
        longitude: Double?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await FirestoreService.shared.updateEvent(
                id: id,
                title: title,
                description: description,
                category: category,
                date: date,
                location: location,
                latitude: latitude,
                longitude: longitude
            )
            await fetchEvents()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func toggleRSVP(event: Event) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let eventId = event.id else { return }
        // Koristi `isAttending` (isti izvor kao UI); `attendees` može biti prazan zbog keša/pravila.
        let currentlyAttending = event.isAttending
        do {
            try await FirestoreService.shared.toggleRSVP(
                eventId: eventId,
                userId: userId,
                isCurrentlyAttending: currentlyAttending
            )
            await fetchEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteEvent(id: String) async {
        do {
            try await FirestoreService.shared.deleteEvent(id: id)
            events.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
