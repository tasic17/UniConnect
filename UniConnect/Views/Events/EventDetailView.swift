import MapKit
import SwiftUI

struct EventDetailView: View {
    let eventId: String
    var navigationPath: Binding<NavigationPath>?
    @EnvironmentObject var eventsVM: EventsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditEvent = false

    private var event: Event? {
        eventsVM.events.first { $0.id == eventId }
    }

    private var isOrganizer: Bool {
        guard let event, let uid = authViewModel.currentUser?.uid else { return false }
        return event.authorId == uid
    }

    var body: some View {
        Group {
            if let event {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        detailRow(label: "Kada", value: event.date.formatted(date: .long, time: .shortened))

                        labeledSection(label: "Opis") {
                            Text(event.description.isEmpty ? "—" : event.description)
                                .font(.body)
                        }

                        detailRow(label: "Adresa", value: event.location)

                        EventDetailMapPreview(
                            title: event.title,
                            address: event.location,
                            latitude: event.latitude,
                            longitude: event.longitude
                        )

                        labeledSection(label: "Prijavljeno") {
                            Text(verbatim: "\(event.attendeesCount)")
                                .font(.body)
                        }

                        labeledSection(label: "Organizator") {
                            AuthorProfileTapRow(
                                userId: event.authorId,
                                fallbackName: event.authorName,
                                navigationPath: navigationPath
                            )
                        }

                        labeledSection(label: "Kategorija") {
                            Text(event.category.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Constants.Colors.primary.opacity(0.15))
                                .foregroundStyle(Constants.Colors.primary)
                                .clipShape(Capsule())
                        }

                        if !isOrganizer {
                            Button {
                                Task { await eventsVM.toggleRSVP(event: event) }
                            } label: {
                                Text(event.isAttending ? "Otkaži dolazak" : "Prijavi se")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Constants.Colors.primary)
                            .disabled(authViewModel.currentUser == nil)
                        }

                        if isOrganizer {
                            Button {
                                eventsVM.errorMessage = nil
                                showEditEvent = true
                            } label: {
                                Text("Uredi događaj")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(Constants.Colors.primary)

                            Button(role: .destructive) {
                                Task {
                                    await eventsVM.deleteEvent(id: eventId)
                                    dismiss()
                                }
                            } label: {
                                Text("Obriši događaj")
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        if let err = eventsVM.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            } else {
                ProgressView("Učitavanje…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(event?.title ?? "Događaj")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditEvent) {
            if let ev = eventsVM.events.first(where: { $0.id == eventId }) {
                EditEventView(event: ev)
                    .environmentObject(eventsVM)
            }
        }
        .task {
            await eventsVM.fetchEvents()
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        labeledSection(label: label) {
            Text(value)
                .font(.body)
        }
    }

    /// Isti razmak naslov → vrednost kao kod „Kada” (4 pt).
    private func labeledSection<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private struct EventDetailMapPreview: View {
    let title: String
    let address: String
    let latitude: Double?
    let longitude: Double?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var geocodeFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lokacija")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let coord = coordinate {
                Map(position: $cameraPosition) {
                    Marker(title, coordinate: coord)
                        .tint(Constants.Colors.primary)
                }
                .mapStyle(.standard)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                        )
                    )
                }
            } else if geocodeFailed {
                Text("Mape nije moguće učitati za ovu adresu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("Učitavanje mape…")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            await loadCoordinate()
        }
    }

    private func loadCoordinate() async {
        if let la = latitude, let lo = longitude, abs(la) > 0.0001, abs(lo) > 0.0001 {
            let c = CLLocationCoordinate2D(latitude: la, longitude: lo)
            coordinate = c
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: c,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
            return
        }
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if let c = await GeocodingHelper.coordinate(for: trimmed) {
                coordinate = c
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: c,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            } else {
                geocodeFailed = true
            }
        } else {
            geocodeFailed = true
        }
    }
}

