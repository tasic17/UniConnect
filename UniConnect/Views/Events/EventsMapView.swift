import MapKit
import SwiftUI

struct EventsMapView: View {
    let events: [Event]
    /// Kada korisnik dodirne marker (otvara detalj događaja).
    var onSelectEvent: (String) -> Void

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.7866, longitude: 20.4489),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    @State private var cameraPosition: MapCameraPosition = .region(Self.defaultRegion)
    @State private var markers: [(id: String, title: String, coordinate: CLLocationCoordinate2D)] = []
    @State private var isResolving = false

    private var eventSignature: String {
        events.compactMap(\.id).sorted().joined(separator: "|")
    }

    var body: some View {
        Group {
            if events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Nema događaja")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if isResolving && markers.isEmpty {
                ProgressView("Učitavanje mape…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if markers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Nema tačaka na mapi")
                        .font(.headline)
                    Text("Ne mogu da nađem adresu na mapi. Proveri adresu ili unesi širinu i dužinu.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Map(position: $cameraPosition) {
                    ForEach(markers, id: \.id) { item in
                        Annotation("", coordinate: item.coordinate) {
                            Button {
                                onSelectEvent(item.id)
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Constants.Colors.primary)
                                    Text(item.title)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 120)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Otvara detalje događaja")
                        }
                    }
                }
                .mapStyle(.standard)
            }
        }
        .task(id: eventSignature) {
            await resolveMarkers()
        }
    }

    private func resolveMarkers() async {
        isResolving = true
        defer { isResolving = false }
        var built: [(id: String, title: String, coordinate: CLLocationCoordinate2D)] = []
        for event in events {
            guard let id = event.id else { continue }
            if let la = event.latitude, let lo = event.longitude, abs(la) > 0.0001, abs(lo) > 0.0001 {
                built.append((
                    id: id,
                    title: event.title,
                    coordinate: CLLocationCoordinate2D(latitude: la, longitude: lo)
                ))
            } else if !event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let coord = await GeocodingHelper.coordinate(for: event.location) {
                    built.append((id: id, title: event.title, coordinate: coord))
                }
            }
        }
        markers = built
        if !built.isEmpty {
            cameraPosition = .region(regionFittingCoordinates(built.map(\.coordinate)))
        } else {
            cameraPosition = .region(Self.defaultRegion)
        }
    }

    private func regionFittingCoordinates(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else { return Self.defaultRegion }
        let minLat = coords.map(\.latitude).min()!
        let maxLat = coords.map(\.latitude).max()!
        let minLon = coords.map(\.longitude).min()!
        let maxLon = coords.map(\.longitude).max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
