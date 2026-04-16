import CoreLocation
import Foundation

enum GeocodingHelper {
    /// Pretvara adresu u koordinate (ne zahteva dozvolu za lokaciju korisnika).
    static func coordinate(for address: String) async -> CLLocationCoordinate2D? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let geocoder = CLGeocoder()
        return await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(trimmed) { placemarks, _ in
                guard let placemark = placemarks?.first, let location = placemark.location else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: location.coordinate)
            }
        }
    }
}
