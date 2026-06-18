import Foundation

/// A drug record surfaced by the openFDA drug-label endpoint.
public struct FDADrug: Identifiable, Hashable, Sendable {
    public let id: String
    public let brandName: String
    public let genericName: String?
    public let route: String?
    public let dosageForms: [String]

    public init(id: String, brandName: String, genericName: String?, route: String?, dosageForms: [String]) {
        self.id = id
        self.brandName = brandName
        self.genericName = genericName
        self.route = route
        self.dosageForms = dosageForms
    }
}

/// Queries the public openFDA drug-label API for brand-name autocomplete.
///
/// An `actor` so concurrent searches from the Add/Edit UI are serialized safely.
/// Every failure path (offline, bad status, malformed JSON, empty query) returns
/// `[]` so callers never have to handle errors — they just show no suggestions.
public actor FDAService {

    public static let shared = FDAService()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// openFDA brand-name search. Returns up to 5 results; `[]` on any failure.
    /// Callers should debounce in the View before invoking.
    public func search(_ query: String) async -> [FDADrug] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        guard let url = makeURL(for: trimmed) else { return [] }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return []
            }
            let decoded = try JSONDecoder().decode(OpenFDAResponse.self, from: data)
            return decoded.results.compactMap { $0.toFDADrug() }
        } catch {
            // Graceful offline / parse-failure fallback per contract.
            return []
        }
    }

    // MARK: URL construction

    private func makeURL(for query: String) -> URL? {
        // search=openfda.brand_name:*QUERY*&limit=5
        var components = URLComponents(string: "https://api.fda.gov/drug/label.json")
        let escaped = query.replacingOccurrences(of: "\"", with: "")
        components?.queryItems = [
            URLQueryItem(name: "search", value: "openfda.brand_name:*\(escaped)*"),
            URLQueryItem(name: "limit", value: "5")
        ]
        return components?.url
    }
}

// MARK: - openFDA JSON shapes (fileprivate decoding models)

private struct OpenFDAResponse: Decodable {
    let results: [Result]

    struct Result: Decodable {
        let id: String?
        let openfda: OpenFDA?

        func toFDADrug() -> FDADrug? {
            guard let openfda, let brand = openfda.brand_name?.first, !brand.isEmpty else {
                return nil
            }
            let identifier = id ?? brand
            return FDADrug(
                id: identifier,
                brandName: brand.capitalized(with: .current),
                genericName: openfda.generic_name?.first?.capitalized(with: .current),
                route: openfda.route?.first?.capitalized(with: .current),
                dosageForms: openfda.dosage_form ?? []
            )
        }
    }

    struct OpenFDA: Decodable {
        let brand_name: [String]?
        let generic_name: [String]?
        let route: [String]?
        let dosage_form: [String]?
    }
}
