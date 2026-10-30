//
//  CampuraOneApp.swift
//  CampuraOne
//
//  Created by LShayc1own on 18/05/2026.
//

import SwiftUI
import SwiftData
import UIKit
import OSLog

@main
struct CampuraOneApp: App {
    @StateObject private var authSession = AuthSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var didCheckIcon = false

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if PreviewAPI.isEnabled {
                PreviewAppView()
            } else {
                liveContent
            }
            #else
            liveContent
            #endif
        }
    }

    private var liveContent: some View {
            AppRootView()
                .environmentObject(authSession)
                .modelContainer(for: [
                            School.self,
                            Campus.self,
                            SchoolCalendar.self,
                            CourseTable.self,
                            AppUser.self,
                            Student.self
                        ])
                .task(id: scenePhase) {
                    guard scenePhase == .active, !didCheckIcon else { return }
                    // At most one attempt per launch; returning from the system alert
                    // must not trigger another icon change.
                    didCheckIcon = true
                    await updateIconForSystemVersion()
                }
    }

    @MainActor
    private func updateIconForSystemVersion() async {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else { return }

        let legacyName = "AppIconLegacy"
        let desiredName: String?
        if #available(iOS 26.0, *) {
            // Restore the primary .icon after an OS upgrade, but do not override
            // any unrelated alternate icon introduced in the future.
            guard application.alternateIconName == legacyName else { return }
            desiredName = nil
        } else {
            guard application.alternateIconName == nil else { return }
            desiredName = legacyName
        }

        do {
            try await application.setAlternateIconName(desiredName)
        } catch {
            // Keep the working current icon. A later app launch can retry.
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "CampuraOne", category: "AppIcon")
                .error("Unable to apply system-specific app icon: \(error.localizedDescription, privacy: .public)")
        }
    }
}
