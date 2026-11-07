import Foundation
import Combine
import CamapKit

@MainActor
final class CampusMapStore: ObservableObject {
    struct Client {
        var school: () async throws -> Int
        var fetch: (Int, String?) async throws -> CampusMapResponse
        var merchants: ((Int) async throws -> CampusMerchantBindings)? = nil
    }

    struct FocusRequest: Identifiable {
        let id = UUID()
        let featureIDs: [String]
    }

    @Published private(set) var focusRequest: FocusRequest?
    @Published private(set) var snapshot: CampusMapSnapshot?
    @Published private(set) var merchants: [CampusMerchantBindings.Entry] = []
    @Published private(set) var merchantError: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var revision = UUID()
    @Published var displayMode: CampusMapDisplayMode = .blended
    @Published var selectedFrameID: String?
    @Published private(set) var placements: [String: TemporaryCampusPlacement] = [:]
    private var userID: Int?
    private var generation = UUID()
    private let client: Client

    init(client: Client) {
        self.client = client
    }

    func bind(userID: Int?) {
        guard self.userID != userID else { return }
        self.userID = userID
        generation = UUID()
        snapshot = nil
        focusRequest = nil
        merchants = []
        merchantError = nil
        selectedFrameID = nil
        displayMode = .blended
        placements = [:]
        errorMessage = nil
        isLoading = false
        revision = UUID()
    }

    struct MerchantMarker: Identifiable {
        let id: String
        let title: String
        let frameID: String
        let point: Point
        let reference: CampusContentReference
        let count: Int
    }

    /// Indoor shops share their building's entry marker, so several floors do
    /// not become an overlapping wall of names on the outdoor campus map.
    var merchantMarkers: [MerchantMarker] {
        guard let document = snapshot?.document else { return [] }
        let features = Dictionary(uniqueKeysWithValues: document.features.map { ($0.id, $0) })
        let groups = Dictionary(grouping: merchants) { $0.mapLocation.buildingId ?? $0.placeID }
        return groups.keys.sorted().compactMap { id in
            guard let entries = groups[id], let first = entries.first,
                  let feature = features[id] ?? features[first.placeID],
                  let reference = first.reference else { return nil }
            let isGroup = entries.count > 1
            let title = isGroup ? (feature.name == "建筑" ? "\(entries.count)家商户" : feature.name)
                : (features[first.placeID]?.name ?? feature.name)
            return MerchantMarker(id: id, title: title, frameID: feature.frameId,
                point: CampusMapGeometry.center(of: feature.geometry.points),
                reference: isGroup ? .place(feature.id) : reference, count: entries.count)
        }
    }

    func clearFocus() { focusRequest = nil }

    func focus(on featureIDs: [String]) {
        guard let document = snapshot?.document else { return }
        let valid = featureIDs.filter { id in document.features.contains { $0.id == id } }
        guard let first = valid.first, let feature = document.features.first(where: { $0.id == first }) else { return }
        selectedFrameID = feature.frameId
        focusRequest = FocusRequest(featureIDs: valid)
    }

    func reload() async {
        guard let userID else { return }
        await load(userID: userID, force: true)
    }

    func merchant(at placeID: String) -> CampusMerchantBindings.Entry? {
        merchants.first { $0.placeID == placeID }
    }

    func routeTarget(for reference: CampusContentReference) -> RoutePreviewTarget? {
        guard let entry = merchants.first(where: { $0.reference?.id == reference.id }),
              let feature = snapshot?.document.features.first(where: { $0.id == entry.placeID }) else { return nil }
        return .place(id: feature.id, name: feature.name, frameID: feature.frameId)
    }

    func setPlacement(_ placement: TemporaryCampusPlacement, frameID: String) {
        guard snapshot?.document.frames.first(where: { $0.id == frameID })?.bindings["mapkit"] == nil else { return }
        placements[frameID] = placement
    }

    func loadIfNeeded() async {
        guard let userID else { return }
        await load(userID: userID)
    }

    func load(userID: Int, force: Bool = false) async {
        bind(userID: userID)
        guard !isLoading, force || snapshot == nil else { return }
        let ticket = generation
        isLoading = true
        errorMessage = nil
        defer { if ticket == generation { isLoading = false } }
        do {
            let schoolID = try await client.school()
            try Task.checkCancellation()
            guard ticket == generation else { return }
            let response = try await client.fetch(schoolID, snapshot?.schoolID == schoolID ? snapshot?.etag : nil)
            try Task.checkCancellation()
            guard ticket == generation else { return }
            switch response {
            case .unchanged:
                guard snapshot?.schoolID == schoolID else { throw APIClientError.invalidResponse }
            case .document(let new):
                try Camap.validate(new.document)
                let changed = snapshot?.document != new.document || snapshot?.hash != new.hash
                snapshot = new
                if changed {
                    placements = [:]
                    merchants = []
                    selectedFrameID = new.document.frames.first(where: { $0.id == selectedFrameID })?.id ?? new.document.frames.first?.id
                    revision = UUID()
                }
            }
            if let fetch = client.merchants {
                do {
                    let catalog = try await fetch(schoolID)
                    try Task.checkCancellation()
                    guard ticket == generation, let snapshot else { return }
                    guard catalog.matches(snapshot) else {
                        throw APIClientError.invalidPayload("商户与地图版本不一致，请刷新地图")
                    }
                    merchants = catalog.validatedEntries(in: snapshot)
                    merchantError = nil
                } catch is CancellationError { }
                catch {
                    if ticket == generation {
                        merchants = []
                        merchantError = error.localizedDescription
                    }
                }
            }
        } catch is CancellationError { }
        catch { if ticket == generation { errorMessage = error.localizedDescription } }
    }
}
