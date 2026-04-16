import SwiftUI

struct EventsListView: View {
    let events: [Event]

    var body: some View {
        Group {
            if events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Nema događaja")
                        .font(.headline)
                    Text("Dodaj novi događaj sa +.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(events) { event in
                        if let id = event.id {
                            NavigationLink {
                                EventDetailView(eventId: id)
                            } label: {
                                EventRowContent(event: event)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct EventRowContent: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(event.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(event.location)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(event.category.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Constants.Colors.primary.opacity(0.12))
                .foregroundStyle(Constants.Colors.primary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
