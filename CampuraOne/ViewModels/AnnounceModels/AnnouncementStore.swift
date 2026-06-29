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

    private var loadedStudentID: Int?

    func load(
        for userProfile: AppUser?,
        force: Bool = false
    ) async {
        guard let studentID = userProfile?.studentID else {
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
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            let student = try await RemoteDataService.shared
                .fetchStudentProfile(
                    studentID: studentID
                )

            let visibleAnnounces = try await RemoteDataService.shared
                .fetchVisibleAnnouncements(
                    schoolID: student.schoolID,
                    departmentID: student.departmentID,
                    classID: student.classID,
                    studentID: student.studentID
                )

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}