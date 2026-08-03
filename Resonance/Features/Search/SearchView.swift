import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var query: String = ""
    @State private var suggestions: [String] = []
    @State private var results: CatalogPage?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var activeItem: CatalogItem?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            if query.isEmpty {
                Section("Trending searches") {
                    ForEach(initialSuggestions, id: \.self) { suggestion in
                        Button {
                            query = suggestion
                            Task { await performSearch() }
                        } label: {
                            Label(suggestion, systemImage: "magnifyingglass")
                        }
                    }
                }
            } else if let results {
                ForEach(results.sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            Button {
                                activeItem = item
                            } label: {
                                CatalogItemRow(item: item)
                            }
                        }
                    }
                }
            } else if isLoading {
                Section { ProgressView() }
            } else if let errorMessage {
                Section(errorMessage) { Button("Try again") { Task { await performSearch() } } }
            } else {
                Section {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            query = suggestion
                            Task { await performSearch() }
                        } label: {
                            Label(suggestion, systemImage: "magnifyingglass")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Artists, songs, albums, playlists")
        .onSubmit(of: .search) {
            Task { await performSearch() }
        }
        .onChange(of: query) { _, newValue in
            Task { await loadSuggestions(for: newValue) }
        }
        .sheet(item: $activeItem) { item in
            CatalogItemDetailSheet(item: item) { _ in }
        }
    }

    private let initialSuggestions: [String] = ["Lo-fi", "Top 50 Global", "Acoustic 2026", "Vocal Jazz", "New This Week"]

    private func loadSuggestions(for text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        do {
            suggestions = try await container.catalogRepository.searchSuggestions(for: trimmed)
        } catch {
            suggestions = []
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            results = try await container.catalogRepository.search(for: trimmed)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            results = nil
        }
        isLoading = false
    }
}

struct CatalogItemRow: View {
    let item: CatalogItem

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: item.artworkURL, size: 48, showsShadow: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
