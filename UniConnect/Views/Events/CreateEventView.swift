import CoreLocation
import SwiftUI

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var eventsVM: EventsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var category = Event.EventCategory.akademski
    @State private var date = Date()
    @State private var location = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Osnovno") {
                    TextField("Naslov", text: $title)
                    Picker("Kategorija", selection: $category) {
                        ForEach(Event.EventCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    DatePicker("Datum i vreme", selection: $date)
                }
                Section("Opis") {
                    TextField("Opis", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    TextField("Adresa ili mesto", text: $location, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Lokacija")
                } footer: {
                    Text("Mapa koristi automatski određene koordinate na osnovu adrese (ako sistem prepozna adresu).")
                        .font(.caption)
                }
                if let err = eventsVM.errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Novi događaj")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Objavi") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(!canSave || eventsVM.isLoading || authViewModel.currentUser == nil)
                }
            }
            .overlay {
                if eventsVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func save() async {
        guard let user = authViewModel.currentUser else { return }
        let address = location.trimmingCharacters(in: .whitespacesAndNewlines)
        var lat: Double?
        var lon: Double?
        if !address.isEmpty, let coord = await GeocodingHelper.coordinate(for: address) {
            lat = coord.latitude
            lon = coord.longitude
        }
        let ok = await eventsVM.createEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            date: date,
            location: address,
            latitude: lat,
            longitude: lon,
            authorId: user.uid,
            authorName: user.displayName
        )
        if ok { dismiss() }
    }
}
