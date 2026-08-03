import Foundation

protocol CatalogRepository: Sendable {
    func home() async throws -> CatalogPage
    func searchSuggestions(for query: String) async throws -> [String]
    func search(for query: String) async throws -> CatalogPage
    func browse(id: String, fallbackTitle: String) async throws -> CatalogPage
}

final class LiveCatalogRepository: CatalogRepository, Sendable {
    private let client: InnerTubeClient
    private let parser = InnerTubeParser()

    init(client: InnerTubeClient) {
        self.client = client
    }

    func home() async throws -> CatalogPage {
        parser.parsePage(try await client.home(), fallbackTitle: "Home")
    }

    func searchSuggestions(for query: String) async throws -> [String] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return parser.parseSuggestions(try await client.searchSuggestions(query: query))
    }

    func search(for query: String) async throws -> CatalogPage {
        parser.parsePage(try await client.search(query: query), fallbackTitle: "Results for “\(query)”")
    }

    func browse(id: String, fallbackTitle: String) async throws -> CatalogPage {
        parser.parsePage(try await client.browse(id: id), fallbackTitle: fallbackTitle)
    }
}
