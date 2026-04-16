import SwiftUI

struct EventsView: View {
    @EnvironmentObject var viewModel: EventsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showMap = false
    @State private var showCreateEvent = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                Picker("Prikaz", selection: $showMap) {
                    Text("Lista").tag(false)
                    Text("Mapa").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "Sve", isSelected: viewModel.selectedCategory == nil) {
                            viewModel.selectedCategory = nil
                        }
                        ForEach(Event.EventCategory.allCases, id: \.self) { cat in
                            FilterChip(title: cat.rawValue, isSelected: viewModel.selectedCategory == cat) {
                                viewModel.selectedCategory = cat
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if showMap {
                    EventsMapView(events: viewModel.filteredEvents) { eventId in
                        navigationPath.append(eventId)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                } else {
                    EventsListView(events: viewModel.filteredEvents)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Događaji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Novi događaj")
                }
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView()
                    .environmentObject(viewModel)
                    .environmentObject(authViewModel)
            }
            .task {
                await viewModel.fetchEvents()
            }
            .refreshable {
                await viewModel.fetchEvents()
            }
            .navigationDestination(for: String.self) { eventId in
                EventDetailView(eventId: eventId)
                    .environmentObject(viewModel)
                    .environmentObject(authViewModel)
            }
        }
    }
}
