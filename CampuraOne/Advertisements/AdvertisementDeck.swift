/// Presentation order only; image snapshots remain owned by AdvertisementStore.
struct AdvertisementDeck: Equatable {
    private(set) var ids: [Int] = []

    mutating func synchronize(with availableIDs: [Int]) {
        let available = Set(availableIDs)
        ids.removeAll { !available.contains($0) }
        var included = Set(ids)
        for id in availableIDs where included.insert(id).inserted {
            ids.append(id)
        }
    }

    mutating func advance(by step: Int) {
        guard ids.count > 1 else { return }
        let offset = (step % ids.count + ids.count) % ids.count
        ids = Array(ids.dropFirst(offset)) + Array(ids.prefix(offset))
    }
}
