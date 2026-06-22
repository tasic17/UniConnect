import CoreLocation
import SwiftUI

struct EditEventView: View {
    let event: Event

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var eventsVM: EventsViewModel

    @State private var title: String
    @State private var descriptionText: String
    @State private var category: Event.EventCategory
    @State private var date: Date
    @State private var location: String

    init(event: Event) {
        self.event = event
        _title = State(initialValue: event.title)
        _descriptionText = State(initialValue: event.description)
        _category = State(initialValue: event.category)
        _date = State(initialValue: event.date)
        _location = State(initialValue: event.location)
    }

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
                    Text("Koordinate se ponovo računaju iz adrese pri čuvanju.")
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
            .navigationTitle("Uredi događaj")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sačuvaj") {
                        Task { await save() }
                    }
                    .disabled(!canSave || eventsVM.isLoading || event.id == nil)
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
        guard let id = event.id else { return }
        let address = location.trimmingCharacters(in: .whitespacesAndNewlines)
        var lat: Double?
        var lon: Double?
        if !address.isEmpty, let coord = await GeocodingHelper.coordinate(for: address) {
            lat = coord.latitude
            lon = coord.longitude
        }
        let ok = await eventsVM.updateEvent(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            date: date,
            location: address,
            latitude: lat,
            longitude: lon
        )
        if ok {
            await Task.yield()
            await MainActor.run { dismiss() }
        }
    }
}
