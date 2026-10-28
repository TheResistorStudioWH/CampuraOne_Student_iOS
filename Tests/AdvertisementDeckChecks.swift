@main struct AdvertisementDeckChecks {
    static func main() {
        var deck = AdvertisementDeck()
        deck.synchronize(with: [1, 2, 3, 4])
        deck.advance(by: 1)
        precondition(deck.ids == [2, 3, 4, 1], "The front card must return to the tail")
        deck.advance(by: -1)
        precondition(deck.ids == [1, 2, 3, 4], "Reverse swipe must restore the preceding card")

        for count in 1...6 {
            var looping = AdvertisementDeck()
            let initial = Array(1...count)
            looping.synchronize(with: initial)
            var visits: [Int: Int] = [:]
            for _ in 0..<(count * 4) {
                visits[looping.ids.first!, default: 0] += 1
                looping.advance(by: 1)
            }
            precondition(looping.ids == initial)
            precondition(visits.count == count && visits.values.allSatisfy { $0 == 4 }, "Every ad must remain reachable across multiple loops")
            for _ in 0..<count { looping.advance(by: -1) }
            precondition(looping.ids == initial)
        }

        deck.advance(by: 1)
        deck.synchronize(with: [4, 3, 1, 5])
        precondition(deck.ids == [3, 4, 1, 5], "Withdraw the current card, retain the surviving order, append new ads")
        deck.synchronize(with: [5, 1, 3, 4, 5])
        precondition(deck.ids == [3, 4, 1, 5], "Polling must not reset the deck or duplicate cards")
        deck.synchronize(with: [5])
        deck.advance(by: 1)
        precondition(deck.ids == [5])
        deck.synchronize(with: [])
        deck.advance(by: -1)
        precondition(deck.ids.isEmpty, "Withdrawing all ads must empty the deck safely")
        print("PASS: ad recycling, bidirectional loops, withdrawal and polling stability (offline)")
    }
}
