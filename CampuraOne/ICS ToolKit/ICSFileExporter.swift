//
//  ICSFileExporter.swift
//  CampuraOne
//
//  Created by Lin Shay on 04/06/2026.
//

///把 ICS 字符串写成临时 .ics 文件，给 ShareLink / 分享按钮使用。

import Foundation

/// ICS 文件导出工具。
///
/// 负责把 `.ics` 字符串写入临时文件，供 SwiftUI 的 `ShareLink` 或系统分享面板使用。
enum ICSFileExporter {
    
    static func makeTemporaryICSFile(
        icsText: String,
        fileName: String = "campura-calendar"
    ) throws -> URL {
        let safeFileName = sanitizedFileName(fileName)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeFileName)
            .appendingPathExtension("ics")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        try icsText.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        
        return fileURL
    }
    
    static func makeTemporaryICSFile(
        events: [ICSEventItem],
        calendarName: String = "Campura One Calendar",
        fileName: String = "campura-calendar"
    ) throws -> URL {
        let icsText = SimpleICSGenerator.generateCalendar(
            events: events,
            calendarName: calendarName
        )
        
        return try makeTemporaryICSFile(
            icsText: icsText,
            fileName: fileName
        )
    }
    
    static func makeTemporaryICSFile(
        event: ICSEventItem,
        calendarName: String = "Campura One Calendar",
        fileName: String? = nil
    ) throws -> URL {
        let icsText = SimpleICSGenerator.generateCalendar(
            event: event,
            calendarName: calendarName
        )
        
        return try makeTemporaryICSFile(
            icsText: icsText,
            fileName: fileName ?? event.title
        )
    }
    
    private static func sanitizedFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let components = fileName.components(separatedBy: invalidCharacters)
        let result = components
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result.isEmpty ? "campura-calendar" : result
    }
}
