import Foundation
import Combine
import CamapKit

@MainActor
final class CampusMapStore: ObservableObject {
    struct Client {
        var school: () async throws -> Int
        var fetch: (Int, String?) async throws -> CampusMapResponse
    }

    @Published private(set) var snapshot: CampusMapSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var revision = UUID()
    @Published var displayMode: CampusMapDisplayMode = .blended
    @Published var selectedFrameID: String?
    @Published private(set) var placements: [String: TemporaryCampusPlacement] = [:]
    private var userID: Int?
    private var generation = UUID()
    private let client: Client

    init(client: Client) { self.client = client }

    func bind(userID: Int?) {
        guard self.userID != userID else { return }
        self.userID = userID
        generation = UUID()
        snapshot = nil
        selectedFrameID = nil
        displayMode = .blended
        placements = [:]
        errorMessage = nil
        isLoading = false
        revision = UUID()
    }

    func setPlacement(_ placement: TemporaryCampusPlacement, frameID: String) {
        guard snapshot?.document.frames.first(where: { $0.id == frameID })?.bindings["mapkit"] == nil else { return }
        placements[frameID] = placement
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
                    selectedFrameID = new.document.frames.first(where: { $0.id == selectedFrameID })?.id ?? new.document.frames.first?.id
                    revision = UUID()
                }
            }
        } catch is CancellationError { }
        catch { if ticket == generation { errorMessage = error.localizedDescription } }
    }
}
