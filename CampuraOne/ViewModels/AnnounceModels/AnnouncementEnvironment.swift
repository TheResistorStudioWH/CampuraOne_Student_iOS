//
//  AnnouncementEnvironment.swift
//  CampuraOne
//
//  Created by Lin Shay on 15/06/2026.
//

import SwiftUI

struct AnnouncementGeometryNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

struct AnnouncementToolbarVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var announcementGeometryNamespace: Namespace.ID? {
        get { self[AnnouncementGeometryNamespaceKey.self] }
        set { self[AnnouncementGeometryNamespaceKey.self] = newValue }
    }
    
    var announcementToolbarVisible: Bool {
        get { self[AnnouncementToolbarVisibleKey.self] }
        set { self[AnnouncementToolbarVisibleKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func announcementMatchedGeometry(
        id: String,
        namespace: Namespace.ID?,
        isSource: Bool
    ) -> some View {
        if let namespace {
            matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: isSource
            )
        } else {
            self
        }
    }
}
