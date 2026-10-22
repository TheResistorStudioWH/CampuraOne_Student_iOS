//
//  AnnouncementStore.swift
//  CampuraOne
//
//  Created by Lin Shay on 15/06/2026.
//

import Foundation
import Combine

@MainActor
final class AnnouncementStore: ObservableObject {
    @Published private(set) var announces: [AnnouncementItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var aiSummary: String?

    private let fetchAnnouncements: (Int) async throws -> [AnnouncementItem]
    private let fetchSummary: () async throws -> AnnouncementSummary
    private let now: () -> Date
    private var studentID: Int?
    private var hasLoaded = false
    private var generation = UUID()
    private var inFlightRequest: UUID?
    private var lifecycle: UUID?
    private var validityTimer: AnyCancellable?
    private var nextListRefresh = Date.distantPast
    private var summaryAttempts = 0
    private var nextSummaryAttempt = Date.distantPast
    private var lastSummaryAttempt: Date?

    // Live loaders are wired in API/RemoteDataService.swift. Tests inject local
    // fixtures and a clock, so no student account or AI credit is required.
    init(
        fetchAnnouncements: @escaping (Int) async throws -> [AnnouncementItem],
        fetchSummary: @escaping () async throws -> AnnouncementSummary,
        now: @escaping () -> Date = Date.init
    ) {
        self.fetchAnnouncements = fetchAnnouncements
        self.fetchSummary = fetchSummary
        self.now = now
    }

    /// Owned by ContentView's foreground task, not by individual banner views.
    func run(for studentID: Int?) async {
        guard !Task.isCancelled else { return }
        pause()
        prepare(for: studentID)
        guard studentID != nil else { return }
        let session = UUID()
        lifecycle = session
        nextListRefresh = .distantPast
        summaryAttempts = 0
        // Rapid background/foreground changes must not create an AI retry storm.
        nextSummaryAttempt = lastSummaryAttempt?.addingTimeInterval(30) ?? .distantPast
        refreshValidity()
        validityTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshValidity() }
        defer {
            if lifecycle == session { pause() }
        }

        while !Task.isCancelled, lifecycle == session {
            await load(for: studentID)
            do { try await Task.sleep(for: .seconds(1)) }
            catch { return }
        }
    }

    func pause() {
        lifecycle = nil
        generation = UUID()
        inFlightRequest = nil
        isLoading = false
        validityTimer?.cancel()
        validityTimer = nil
    }

    func load(for studentID: Int?, force: Bool = false) async {
        guard !Task.isCancelled else { return }
        prepare(for: studentID)
        refreshValidity()
        guard let studentID, !Task.isCancelled, inFlightRequest == nil else { return }
        if force {
            nextListRefresh = .distantPast
            summaryAttempts = 0
            nextSummaryAttempt = .distantPast
        }

        let request = UUID()
        let sessionGeneration = generation
        inFlightRequest = request
        defer {
            if inFlightRequest == request {
                inFlightRequest = nil
                isLoading = false
            }
        }

        if now() >= nextListRefresh {
            isLoading = announces.isEmpty
            errorMessage = nil
            do {
                let items = try await fetchAnnouncements(studentID)
                guard isCurrent(request, generation: sessionGeneration) else { return }
                replaceAnnouncements(items.active(at: now()))
                hasLoaded = true
                nextListRefresh = now().addingTimeInterval(60)
                isLoading = false
            } catch {
                guard isCurrent(request, generation: sessionGeneration) else { return }
                errorMessage = error.localizedDescription
                nextListRefresh = now().addingTimeInterval(30)
                return
            }
        }

        // List freshness and summary success are separate. A cached list must
        // never suppress a failed summary's retries (5s, then 30s; max 3 attempts).
        guard hasLoaded, !announces.isEmpty, aiSummary == nil,
              summaryAttempts < 3, now() >= nextSummaryAttempt else { return }
        let sources = announces
        summaryAttempts += 1
        lastSummaryAttempt = now()
        do {
            let response = try await fetchSummary()
            guard isCurrent(request, generation: sessionGeneration) else { return }
            refreshValidity()
            // A notice can expire or be withdrawn/edited while AI is generating.
            guard announces == sources else { return }
            let text = response.summary
                .replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard response.isAI, !response.sourceIDs.isEmpty,
                  Set(response.sourceIDs).isSubset(of: Set(sources.map(\.announceID))),
                  !text.isEmpty else {
                summaryFailed()
                return
            }
            aiSummary = text
        } catch {
            guard isCurrent(request, generation: sessionGeneration) else { return }
            refreshValidity()
            guard announces == sources else { return }
            summaryFailed()
        }
    }

    /// Also runs while a slow network request is in flight, so expired items
    /// disappear from both badges and open sheets without waiting for the API.
    func refreshValidity() {
        replaceAnnouncements(announces.active(at: now()))
    }

    private func prepare(for id: Int?) {
        guard studentID != id else { return }
        generation = UUID()
        inFlightRequest = nil
        studentID = id
        hasLoaded = false
        announces = []
        aiSummary = nil
        errorMessage = nil
        isLoading = false
        nextListRefresh = .distantPast
        summaryAttempts = 0
        nextSummaryAttempt = .distantPast
        lastSummaryAttempt = nil
    }

    private func replaceAnnouncements(_ items: [AnnouncementItem]) {
        let sorted = items.sorted {
            if $0.endTime != $1.endTime {
                return ($0.endTime ?? .distantFuture) < ($1.endTime ?? .distantFuture)
            }
            return $0.announceID < $1.announceID
        }
        guard sorted != announces else { return }
        announces = sorted
        aiSummary = nil
        summaryAttempts = 0
        nextSummaryAttempt = .distantPast
    }

    private func summaryFailed() {
        aiSummary = nil // The existing banner continues to show “摘要不可用”.
        nextSummaryAttempt = now().addingTimeInterval(summaryAttempts == 1 ? 5 : 30)
    }

    private func isCurrent(_ request: UUID, generation expected: UUID) -> Bool {
        !Task.isCancelled && generation == expected && inFlightRequest == request
    }
}
