import Foundation

private final class BundleToken {}

extension Bundle {
    static let module: Bundle = {
        let bundleName = "Resonance_ResonanceTests"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleToken.self).resourceURL
        ]
        for candidate in candidates ?? [] {
            for suffix in ["", "/Resources", "/Resonance_ResonanceTests.bundle"] {
                let path = candidate.appendingPathComponent(bundleName + suffix)
                if let bundle = Bundle(path: path.path) { return bundle }
            }
        }
        return Bundle(for: BundleToken.self)
    }()
}
