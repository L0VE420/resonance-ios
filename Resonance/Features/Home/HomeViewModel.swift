import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded(CatalogPage)
        case error(String)
    }

    @Published var phase: Phase = .idle

    private let catalog: any CatalogRepository

    init(catalog: any CatalogRepository) {
        self.catalog = catalog
    }

    func load() async {
        if case .loading = phase { return }
        phase = .loading
        do {
            let page = try await catalog.home()
            phase = .loaded(page)
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
