//
//  AnnouncementStore.swift
//  CampuraOne
//
//  Created by Lin Shay on 15/06/2026.
//


import Foundation
import Combine
import SwiftyJSON

@MainActor
final class AnnouncementStore: ObservableObject {
    @Published private(set) var announces: [AnnouncementItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var aiSummary: String?
    private var generation = UUID()

    private var loadedStudentID: Int?

    func load(
        for userProfile: AppUser?,
        force: Bool = false
    ) async {
        guard let studentID = userProfile?.studentID else {
            generation = UUID()
            aiSummary = nil
            isLoading = false
            announces = []
            errorMessage = nil
            loadedStudentID = nil
            return
        }

        if !force,
           loadedStudentID == studentID,
           !announces.isEmpty {
            return
        }

        isLoading = true
        let request = UUID()
        generation = request
        aiSummary = nil
        if loadedStudentID != studentID { announces = [] }
        errorMessage = nil
        defer {
            if generation == request { isLoading = false }
        }

        do {
            let student = try await RemoteDataService.shared
                .fetchMyStudentProfile()

            let visibleAnnounces = try await RemoteDataService.shared
                .fetchVisibleAnnouncements(
                    schoolID: student.schoolID,
                    departmentID: student.departmentID,
                    classID: student.classID,
                    studentID: student.studentID
                )

            guard generation == request, !Task.isCancelled else { return }
            announces = visibleAnnounces
                .filter {
                    $0.type.isShortAnnouncement ||
                    $0.type.isMarkdown
                }
                .sorted {
                    ($0.endTime ?? .distantFuture) <
                    ($1.endTime ?? .distantFuture)
                }

            loadedStudentID = studentID
            isLoading = false
            // Server authorizes the audience and caches identical source sets.
            if !announces.isEmpty {
                do {
                    let result = try await APIClient.shared.get(
                        url: APIConfig.api_download("/announcement_summary.php")
                    )
                    guard generation == request, !Task.isCancelled else { return }
                    let text = result["data"]["summary"].stringValue
                    let sourceIDs = result["data"]["sourceIDs"].arrayValue.compactMap(\.int)
                    let visibleIDs = Set(announces.map(\.announceID))
                    guard Set(sourceIDs).isSubset(of: visibleIDs), !text.isEmpty else { return }
                    aiSummary = result["data"]["isAI"].boolValue
                        ? "AI 摘要（以原文为准）：\(text)" : text
                } catch {
                    // Keep the original notice count; never replace real notices with an AI error.
                }
            }
        } catch {
            guard generation == request else { return }
            errorMessage = error.localizedDescription
        }
    }
}
