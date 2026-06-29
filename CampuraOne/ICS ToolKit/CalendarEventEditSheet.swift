//
//  CalendarEventEditSheet.swift
//  CampuraOne
//
//  Created by Lin Shay on 04/06/2026.
//

///封装 EventKitUI，用来弹出“添加到系统日历”的页面。

import SwiftUI
import Combine
import EventKit
import EventKitUI

/// 用 SwiftUI 包装 EventKitUI 的事件编辑页面。
///
/// 用途：用户点击“添加到系统日历”后，弹出系统日历事件编辑页。
/// 用户可以自己选择日历、修改标题/时间/地点，然后点“添加”。
struct CalendarEventEditSheet: UIViewControllerRepresentable {
    let event: ICSEventItem
    let eventStore: EKEventStore
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let viewController = EKEventEditViewController()
        viewController.eventStore = eventStore
        viewController.event = makeEKEvent()
        viewController.editViewDelegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(
        _ uiViewController: EKEventEditViewController,
        context: Context
    ) {
        // 系统编辑页不需要跟随 SwiftUI 状态实时刷新。
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator {
            dismiss()
        }
    }
    
    private func makeEKEvent() -> EKEvent {
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.location = event.location
        ekEvent.notes = event.detail
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        
        if let startDate = event.startDate {
            ekEvent.startDate = startDate
        } else {
            ekEvent.startDate = Date()
        }
        
        if let endDate = event.endDate {
            ekEvent.endDate = endDate
        } else {
            ekEvent.endDate = ekEvent.startDate.addingTimeInterval(60 * 60)
        }
        
        ekEvent.isAllDay = event.isAllDay
        
        return ekEvent
    }
    
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void
        
        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }
        
        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onFinish()
        }
    }
}

/// 日历事件编辑页的权限和弹窗状态管理器。
@MainActor
final class CalendarEventEditPresenter: ObservableObject {
    @Published var selectedEvent: ICSEventItem?
    @Published var errorMessage: String?
    
    let eventStore = EKEventStore()
    
    func present(event: ICSEventItem) async {
        do {
            let granted = try await requestCalendarAccessIfNeeded()
            
            if granted {
                selectedEvent = event
            } else {
                errorMessage = "没有获得日历访问权限，暂时无法添加到系统日历。"
            }
        } catch {
            errorMessage = "请求日历权限失败：\(error.localizedDescription)"
        }
    }
    
    private func requestCalendarAccessIfNeeded() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            if #available(iOS 17.0, *) {
                return try await eventStore.requestWriteOnlyAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        case .fullAccess:
            return true
        case .writeOnly:
            return true
        @unknown default:
            return false
        }
    }
}
