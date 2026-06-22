import CoreLocation
import Foundation
import MapKit

enum GeocodingHelper {
    /// Pretvara adresu u koordinate (MapKit pretraga; ne zahteva dozvolu za lokaciju korisnika).
    static func coordinate(for address: String) async -> CLLocationCoordinate2D? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }
}
