import Foundation
import Combine

@MainActor
final class ContentPreviewPage: ObservableObject, Identifiable {
    let id = UUID()
    let reference: CampusContentReference
    let advertisement: Advertisement?
    let model: LoadableListViewModel<ContentPreviewDetail>
    @Published var categoryID: Int?
    @Published var placeLevelID: String?
    @Published var placeQuery = ""
    @Published var scrollID: String?

    init(reference: CampusContentReference, advertisement: Advertisement? = nil, repository: ContentPreviewRepository) {
        self.reference = reference
        self.advertisement = advertisement
        model = LoadableListViewModel { [try await repository.detail(reference)] }
    }
}

@MainActor
final class ContentBrowserStore: ObservableObject {
    @Published private(set) var pages: [ContentPreviewPage] = []
    @Published private(set) var recent: RecentlyViewedItem?
    @Published var panelHeight: Double = 0
    let repository: ContentPreviewRepository
    private var userID: Int?

    var current: ContentPreviewPage? { pages.last }
    var isPresented: Bool { !pages.isEmpty }

    init(repository: ContentPreviewRepository) { self.repository = repository }

    func bind(userID: Int?) {
        guard self.userID != userID else { return }
        self.userID = userID
        close(); recent = nil
        repository.bind(userID: userID)
    }

    func open(_ reference: CampusContentReference, advertisement: Advertisement? = nil) {
        guard userID != nil else { return }
        pages = [ContentPreviewPage(reference: reference, advertisement: advertisement, repository: repository)]
    }

    func push(_ reference: CampusContentReference) {
        guard current?.reference.id != reference.id else { return }
        pages.append(ContentPreviewPage(reference: reference, repository: repository))
    }

    func back() { if pages.count > 1 { pages.removeLast() } else { close() } }
    func close() { pages = []; panelHeight = 0 }

    func didLoad(_ page: ContentPreviewPage) {
        guard pages.contains(where: { $0 === page }), let detail = page.model.items.first else { return }
        if let event = detail.promotion { recent = .sale(event) }
        else if let product = detail.product { recent = .product(product) }
    }
}
