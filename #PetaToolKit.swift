//
//  #PetaToolKit.swift
//  SpotWords
//
//  Created by LShayc1own on 2026/3/12.
//

import Foundation
import SwiftUI
import Combine
import UIKit


// MARK: - 深浅色模式DIY

struct AdaptiveForegroundColorModifier: ViewModifier {
    var lightModeColor: Color
    var darkModeColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content.foregroundColor(resolvedColor)
    }
    
    private var resolvedColor: Color {
        switch colorScheme {
        case .light:
            return lightModeColor
        case .dark:
            return darkModeColor
        @unknown default:
            return lightModeColor
        }
    }
}
enum mystyle {
    case label
    case background
}
extension View {
    func foregroundColorScheme(
        light lightModeColor: Color,
        dark darkModeColor: Color
    ) -> some View {
        modifier(AdaptiveForegroundColorModifier(
            lightModeColor: lightModeColor,
            darkModeColor: darkModeColor
        ))
    }
    
    
}

/// 根据深浅色模式切换的值
struct ColorSchemeValue<Value> {
    
    /// 浅色模式下的值
    let light: Value
    
    /// 深色模式下的值
    let dark: Value
    
    init(light: Value, dark: Value) {
        self.light = light
        self.dark = dark
    }
    
    /// 根据当前深浅色模式返回对应的值
    func value(_ colorScheme: ColorScheme) -> Value {
        colorScheme == .dark ? dark : light
    }
}



extension Double {
    static func colorScheme(
            light: Double,
            dark: Double,
            _ colorScheme: ColorScheme
        ) -> Double {
            colorScheme == .dark ? dark : light
        }
}

extension CGFloat {
    static func colorScheme(
        light: CGFloat,
        dark: CGFloat,
        _ colorScheme: ColorScheme
    ) -> CGFloat {
        
        colorScheme == .dark ? dark : light
    }
}


extension CGSize {
    
    static func colorScheme(
        light: CGSize,
        dark: CGSize,
        _ colorScheme: ColorScheme
    ) -> CGSize {
        
        colorScheme == .dark ? dark : light
    }
}


// MARK: - 时间

class ClassNowTime {
        let currentTime: Date
        let timeInterval: TimeInterval
        let timeInDouble: Double
        let dateString: String
        let timeString:String
        let formatter = DateFormatter()
        
        init() {
            currentTime = Date()
            timeInterval = currentTime.timeIntervalSinceReferenceDate
            timeInDouble = Double(timeInterval)
            formatter.dateStyle = .long
            formatter.timeStyle = .long
            formatter.dateFormat = "yyyy年MM月dd日"
            dateString = formatter.string(from: Date())
            formatter.dateFormat = "HH:mm"
            timeString = formatter.string(from: Date())
        }
    }

let screen = UIScreen.main.bounds

struct SimulatorInfo {

    static let env = ProcessInfo.processInfo.environment

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    static var deviceName: String {
        env["SIMULATOR_DEVICE_NAME"] ?? "Unknown"
    }

    static var modelIdentifier: String {
        env["SIMULATOR_MODEL_IDENTIFIER"] ?? "Unknown"
    }
}

// MARK: - watch适配
#if os(watchOS)
import WatchKit

extension WKInterfaceDevice {

    var deviceGroup: WatchDeviceGroup {

        let watchInfo = getWatchModel()

        print("📱⌚️Device Name:", SimulatorInfo.deviceName)
        print("Watch Info:", watchInfo)

        // 小尺寸设备
        if watchInfo.name.contains("SE")
            || watchInfo.name.contains("Series 4")
            || watchInfo.name.contains("Series 5") {

            return .compact
        }

        return .regular
    }

    func getWatchModel() -> WatchInfo {

        // MARK: - Simulator

        if SimulatorInfo.isSimulator {

            let simulatorName = SimulatorInfo.deviceName

            // 直接根据模拟器名称匹配
            if let matched = nameMap.first(where: {
                simulatorName.contains($0.name)
                && simulatorName.contains($0.size)
            }) {

                return matched
            }

            // 兜底：仅匹配名称
            if let matched = nameMap.first(where: {
                simulatorName.contains($0.name)
            }) {

                return matched
            }

            return WatchInfo(
                num: "Simulator",
                name: simulatorName,
                net: "",
                size: ""
            )
        }

        // MARK: - Real Device

        var size: size_t = 0

        sysctlbyname("hw.machine", nil, &size, nil, 0)

        var machine = [CChar](repeating: 0, count: size)

        sysctlbyname("hw.machine", &machine, &size, nil, 0)

        let watchModel = String(
            cString: &machine,
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? WKInterfaceDevice.current().name

        let foundWatchInfo = nameMap.first {
            $0.num == watchModel
        }

        return foundWatchInfo
        ?? WatchInfo(
            num: watchModel,
            name: "Apple Watch",
            net: "",
            size: ""
        )
    }

    private var nameMap: [WatchInfo] {

        [
            WatchInfo(num: "Watch4,1", name: "Apple Watch Series 4", net: "GPS", size: "40 mm"),
            WatchInfo(num: "Watch4,2", name: "Apple Watch Series 4", net: "Cellular", size: "40 mm"),
            WatchInfo(num: "Watch4,3", name: "Apple Watch Series 4", net: "GPS", size: "44 mm"),
            WatchInfo(num: "Watch4,4", name: "Apple Watch Series 4", net: "Cellular", size: "44 mm"),

            WatchInfo(num: "Watch5,1", name: "Apple Watch Series 5", net: "GPS", size: "40 mm"),
            WatchInfo(num: "Watch5,2", name: "Apple Watch Series 5", net: "Cellular", size: "40 mm"),
            WatchInfo(num: "Watch5,3", name: "Apple Watch Series 5", net: "GPS", size: "44 mm"),
            WatchInfo(num: "Watch5,4", name: "Apple Watch Series 5", net: "Cellular", size: "44 mm"),

            WatchInfo(num: "Watch5,9", name: "Apple Watch SE", net: "GPS", size: "40 mm"),
            WatchInfo(num: "Watch5,10", name: "Apple Watch SE", net: "GPS", size: "44 mm"),
            WatchInfo(num: "Watch5,11", name: "Apple Watch SE", net: "Cellular", size: "40 mm"),
            WatchInfo(num: "Watch5,12", name: "Apple Watch SE", net: "Cellular", size: "44 mm"),

            WatchInfo(num: "Watch6,18", name: "Apple Watch Ultra", net: "Cellular", size: "49 mm"),

            WatchInfo(num: "Watch7,5", name: "Apple Watch Ultra 2", net: "Cellular", size: "49 mm"),

            WatchInfo(num: "Watch7,12", name: "Apple Watch Ultra 3", net: "Cellular", size: "49 mm"),

            WatchInfo(num: "Watch7,13", name: "Apple Watch SE 3", net: "GPS", size: "40 mm"),
            WatchInfo(num: "Watch7,14", name: "Apple Watch SE 3", net: "GPS", size: "44 mm")
        ]
    }
}


enum WatchDeviceGroup {
    case compact
    case regular
}
// MARK: - 手表信息
struct WatchInfo {
    var num: String
    var name: String
    var net: String
    var size: String
}


extension CGFloat {
    
    static func WatchSizeAdapter(
        regular: CGFloat,
        compact: CGFloat
    ) -> CGFloat {
        
        WKInterfaceDevice.current().deviceGroup == .compact
        ? compact
        : regular
    }
}

extension CGSize {
    
    static func watch(
        regular: CGSize,
        compact: CGSize
    ) -> CGSize {
        
        WKInterfaceDevice.current().deviceGroup == .compact
        ? compact
        : regular
    }
}

#endif



extension View {
    ///NavigationLink
    @ViewBuilder
    func jumpView<V:View>(to View:V) -> some View {
        NavigationLink(destination: { View }) {
            self
        }
    }
    @ViewBuilder
    func beButton(_ toDo:@escaping () -> ()) -> some View {
        Button(action: toDo) {
            self
        }
    }
    
    @ViewBuilder
    func pointList() -> some View {
        HStack {
            Text("· ")
                .font(.largeTitle)
                .fontWeight(.black)
            self
        }
    }
    
    @ViewBuilder
        func cleanListRow() -> some View {
            self
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(EmptyView())
        }
}


/// GCD延时操作
///   - after: 延迟的时间
///   - handler: 事件
@MainActor
public func DispatchAfter(after: Double, handler: @escaping ()->())
{
    DispatchQueue.main.asyncAfter(deadline: .now() + after) {
        handler()
    }
}

///点标题折叠 Section
struct CollapsibleSection<Content: View, FootContent: View>: View {

    let title: String
    @ViewBuilder let content: Content
    @ViewBuilder let footContent: FootContent

    @State var isExpanded = true

    var body: some View {

        Section {

            if isExpanded {
                content
            }

        } header: {

            HStack {

                Text(title)

                Spacer()

                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut, value: isExpanded)
            }
            .beButton {
                withAnimation {
                    isExpanded.toggle()
                }

            }
            .buttonStyle(.plain)
                
            
        } footer: {
            footContent
        }
    }
}


///HEX转换Color
///转换为Color类型
///多用于Color需要被SwiftData/CoreData以及其他数据储存架构储存的情况,在UI显示时需要把ColorHEX转换为Swift可用的Color类型
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}



// MARK: - iPhone震动马达
func TapSucceed() {
    TapLight()
    DispatchAfter(after: 0.2) {
        TapRigid()
    }
}
func TapMedium() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
}
func TapHeavy() {
    let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                generator.impactOccurred()
}
func TapRigid() {
    let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.prepare()
                generator.impactOccurred()
}
func TapSoft() {
    let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.prepare()
                generator.impactOccurred()
}
func TapLight() {
    let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
}


// MARK: - ForEachWithIndex

public struct ForEachWithIndex<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    public var data: Data
    public var content: (_ index: Data.Index, _ element: Data.Element) -> Content
    var id: KeyPath<Data.Element, ID>
    
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, content: @escaping (_ index: Data.Index, _ element: Data.Element) -> Content) {
        self.data = data
        self.id = id
        self.content = content
    }
    
    public var body: some View {
        ForEach(
            zip(self.data.indices, self.data).map { index, element in
                IndexInfo(
                    index: index,
                    id: self.id,
                    element: element
                )
            },
            id: \.elementID
        ) { indexInfo in
            self.content(indexInfo.index, indexInfo.element)
        }
    }
}

extension ForEachWithIndex where ID == Data.Element.ID, Content: View, Data.Element: Identifiable {
    public init(_ data: Data, @ViewBuilder content: @escaping (_ index: Data.Index, _ element: Data.Element) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

extension ForEachWithIndex: DynamicViewContent where Content: View {
}

private struct IndexInfo<Index, Element, ID: Hashable>: Hashable {
    let index: Index
    let id: KeyPath<Element, ID>
    let element: Element
    
    var elementID: ID {
        self.element[keyPath: self.id]
    }
    
    static func == (_ lhs: IndexInfo, _ rhs: IndexInfo) -> Bool {
        lhs.elementID == rhs.elementID
    }
    
    func hash(into hasher: inout Hasher) {
        self.elementID.hash(into: &hasher)
    }
}
