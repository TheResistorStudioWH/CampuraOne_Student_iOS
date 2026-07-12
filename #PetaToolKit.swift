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

// MARK: - 弹窗
#Preview("ToastAlertView", body: {
    ToastAlertView(symbol: "⚠️", bgColor: .red, message: "警告警告", isAnimating: true)
})

struct ToastAlertView: View {
    var symbol: String
    var bgColor: Color
    let message: String
    @State var isAnimating: Bool
    
    var body: some View {
        Text("\(symbol)" + (message))
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .scaleEffect(isAnimating ? 1 : 0.001)
            .padding(16)
            .padding(.horizontal)
            .background {
                ZStack {
                    
                    RoundedRectangle(cornerRadius: .infinity, style: .continuous)
                        .fill(Material.bar)
                        .shadow(color: .black.opacity(0.33), radius: 8, x: 1, y: 1)
                    RoundedRectangle(cornerRadius: .infinity, style: .continuous)
                        .fill(bgColor.opacity(0.2))
                        .shadow(color: bgColor.opacity(0.1), radius: 8, x: 1, y: 1)
                }
            }
            .padding(.bottom)
    }
}


// MARK: - 🎉buttonStyle

public extension Color {
    static func random(randomOpacity: Bool = false) -> Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            opacity: randomOpacity ? .random(in: 0...1) : 1
        )
    }
}

class ConfettiCenterVM: ObservableObject {
    /// - Parameters:
    ///  - counter: on any change of this variable the animation is run
    ///  - num: amount of confettis
    ///  - colors: list of colors that is applied to the default shapes
    ///  - confettiSize: size that confettis and emojis are scaled to
    ///  - dropHeight: vertical distance that confettis pass
    ///  - fadesOut: reduce opacity towards the end of the animation
    ///  - fireworkEffect: every item will explosive in same circle line
    ///  - opacity: maximum opacity that is reached during the animation
    ///  - openingAngle: boundary that defines the opening angle in degrees
    ///  - closingAngle: boundary that defines the closing angle in degrees
    ///  - radius: explosion radius
    ///  - repetitions: number of repetitions of the explosion
    ///  - repetitionInterval: duration between the repetitions
    @Published var confettiNumber: Int
    @Published var confettiTypes: [ConfettiType]
    @Published var colors: [Color]
    @Published var confettiSize: CGFloat
    @Published var dropHeight: CGFloat
    @Published var fadesOut: Bool
    @Published var fireworkEffect: Bool
    @Published var opacity: Double
    @Published var openingAngle: Angle
    @Published var closingAngle: Angle
    @Published var radius: CGFloat
    @Published var repetitions: Int
    @Published var repetitionInterval: Double
    @Published var explosionAnimationDuration: Double
    @Published var dropAnimationDuration: Double

    init(confettiNumber: Int = 200,
         confettiTypes: [ConfettiType] = ConfettiType.allCases,
         colors: [Color] = [Color.red, Color.blue, Color.pink, Color.green, Color.yellow, Color.indigo, Color.cyan, Color.white, Color.gray, Color.mint, Color.orange, Color.teal, Color.purple, Color.orange, Color.black],
         confettiSize: CGFloat = 12,
         dropHeight: CGFloat = screen.height*1.7,
         fadesOut: Bool = true,
         fireworkEffect: Bool = false,
         opacity: Double = 1.0,
         openingAngle: Angle = .degrees(60),
         closingAngle: Angle = .degrees(120),
         radius: CGFloat = screen.width*1.8,
         repetitions: Int = 0,
         repetitionInterval: Double = 1.0,
         explosionAnimDuration: Double = 0.4,
         dropAnimationDuration: Double = 4.3
    ) {
        self.confettiNumber = confettiNumber
        self.confettiTypes = confettiTypes
        self.colors = colors
        self.confettiSize = confettiSize
        self.dropHeight = dropHeight
        self.fadesOut = fadesOut
        self.fireworkEffect = fireworkEffect
        self.opacity = opacity
        self.openingAngle = openingAngle
        self.closingAngle = closingAngle
        self.radius = radius
        self.repetitions = repetitions
        self.repetitionInterval = repetitionInterval
        self.explosionAnimationDuration = explosionAnimDuration
        self.dropAnimationDuration = dropAnimationDuration
    }
    func getShapes() -> [AnyView] {
        var shapes = [AnyView]()
        for confetti in confettiTypes {
            for color in colors {
                switch confetti {
                case .shape(_):
                    shapes.append(AnyView(confetti.view.foregroundColor(color).frame(width: confettiSize, height: confettiSize, alignment: .center)))
                default:
                    shapes.append(AnyView(confetti.view.foregroundColor(color).font(.system(size: confettiSize))))
                }
            }
        }
        return shapes
    }
    func getAnimDuration() -> CGFloat {
        return explosionAnimationDuration + dropAnimationDuration
    }
}

public enum ConfettiType: CaseIterable, Hashable {
    public enum Shape {
        case circle
        case triangle
        case square
        case slimRectangle
        case roundedCross
    }
    
    case shape(Shape)
    case text(String)
    case sfSymbol(symbolName: String)
    
    public var view:AnyView {
        switch self {
        case .shape(.square):
            return AnyView(Rectangle())
        case .shape(.triangle):
            return AnyView(Triangle())
        case .shape(.slimRectangle):
            return AnyView(SlimRectangle())
        case .shape(.roundedCross):
            return AnyView(RoundedCross())
        case let .text(text):
            return AnyView(Text(text))
        case .sfSymbol(let symbolName):
            return AnyView(Image(systemName: symbolName))
        default:
            return AnyView(Circle())
        }
    }
    public static var allCases: [ConfettiType] {
        return [.shape(.circle), .shape(.triangle), .shape(.square), .shape(.slimRectangle), .shape(.roundedCross)]
    }
}

public struct Triangle: Shape {
    public func path(in rect: CGRect) -> Path {
        
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

public struct RoundedCross: Shape {
    public func path(in rect: CGRect) -> Path {
        
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY/3))
        path.addQuadCurve(to: CGPoint(x: rect.maxX/3, y: rect.minY), control: CGPoint(x: rect.maxX/3, y: rect.maxY/3))
        path.addLine(to: CGPoint(x: 2*rect.maxX/3, y: rect.minY))
        
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY/3), control: CGPoint(x: 2*rect.maxX/3, y: rect.maxY/3))
        path.addLine(to: CGPoint(x: rect.maxX, y: 2*rect.maxY/3))

        path.addQuadCurve(to: CGPoint(x: 2*rect.maxX/3, y: rect.maxY), control: CGPoint(x: 2*rect.maxX/3, y: 2*rect.maxY/3))
        path.addLine(to: CGPoint(x: rect.maxX/3, y: rect.maxY))

        path.addQuadCurve(to: CGPoint(x: 2*rect.minX/3, y: 2*rect.maxY/3), control: CGPoint(x: rect.maxX/3, y: 2*rect.maxY/3))
        return path
    }
}

public struct SlimRectangle: Shape {
    public func path(in rect: CGRect) -> Path {
        
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: 4*rect.maxY/5))
        path.addLine(to: CGPoint(x: rect.maxX, y: 4*rect.maxY/5))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

struct ConfettiView: View {
    
    @Binding var counter: Int
    @StateObject var confettiVM = ConfettiCenterVM()
    @State var animate = 0
    @State var finishedAnimationCounter = 0
    @State var firstAppear = false
    
    var body: some View {
        ZStack {
            ForEach(finishedAnimationCounter..<animate, id:\.self){ i in
                ConfettiContainer(
                    confettiVM: confettiVM, finishedAnimationCounter: $finishedAnimationCounter
                )
            }
        }
        .onAppear(){
            firstAppear = true
        }
        .onChange(of: counter) { value in
            if firstAppear {
                for i in 0...confettiVM.repetitions {
                    DispatchQueue.main.asyncAfter(deadline: .now() + confettiVM.repetitionInterval * Double(i)) {
                        animate += 1
                    }
                }
            }
        }
    }
}

struct ConfettiContainer: View {
    
    @StateObject var confettiVM: ConfettiCenterVM
    @Binding var finishedAnimationCounter:Int
    @State var firstAppear = true

    var body: some View {
        ZStack {
            ForEach(0..<confettiVM.confettiNumber, id:\.self) { _ in
                ConfettiFrame(confettiVM: confettiVM)
            }
        }
        .onAppear {
            if firstAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + confettiVM.getAnimDuration()) {
                    self.finishedAnimationCounter += 1
                }
                firstAppear = false
            }
        }
    }
}

struct ConfettiFrame: View {
    //For Animation.timingCurve
    //https://matthewlein.com/tools/ceaser
    @StateObject var confettiVM: ConfettiCenterVM
    @State var location: CGPoint = CGPoint(x: 0, y: 0)
    @State var opacity: Double = 0.0

    var body: some View {
        ConfettiItem(shape: getShape(), color: getColor())
            .offset(x: location.x, y: location.y)
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.timingCurve(0.6, 1, 1, 1, duration: getAnimationDuration())) {
                
                    opacity = confettiVM.opacity
                    
                    let randomAngle:CGFloat
                    if confettiVM.openingAngle.degrees <= confettiVM.closingAngle.degrees {
                        randomAngle = CGFloat.random(in: CGFloat(confettiVM.openingAngle.degrees)...CGFloat(confettiVM.closingAngle.degrees))
                    } else {
                        randomAngle = CGFloat.random(in: CGFloat(confettiVM.openingAngle.degrees)...CGFloat(confettiVM.closingAngle.degrees + 360)).truncatingRemainder(dividingBy: 360)
                    }
                    
                    let distance = getDistance()
                    
                    location.x = distance * cos(deg2rad(randomAngle))
                    location.y = -distance * sin(deg2rad(randomAngle))
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + getDelayBeforeDropAnimation()) {
                    withAnimation(Animation.timingCurve(0.12, 0, 0.39, 0, duration: confettiVM.dropAnimationDuration)) {
                        location.y += confettiVM.dropHeight
                        opacity = confettiVM.fadesOut ? 0 : confettiVM.opacity
                    }
                }
            }
    }
    func getShape() -> AnyView {
        return confettiVM.getShapes().randomElement()!
    }
    func getColor() -> Color {
        return confettiVM.colors.randomElement()!
    }
    func getRandomExplosionTimeVariation() -> CGFloat {
        return CGFloat((0...999).randomElement()!) / 2100
    }
    func getAnimationDuration() -> CGFloat {
        return 0.2 + confettiVM.explosionAnimationDuration + getRandomExplosionTimeVariation()
    }
    func getDistance() -> CGFloat {
        if !confettiVM.fireworkEffect{
            return pow(CGFloat.random(in: 0.01...1), 2.0/7.0) * confettiVM.radius
        }
        return confettiVM.radius
    }
    func getDelayBeforeDropAnimation() -> TimeInterval {
        confettiVM.explosionAnimationDuration * 0.1
    }
    func deg2rad(_ number: CGFloat) -> CGFloat {
        return number * CGFloat.pi / 180
    }
}

struct ConfettiItem: View {
    
    @State var shape: AnyView
    @State var color: Color
    
    @State var move = false
    @State var anchor = CGFloat(Int.random(in: 0...1))
    @State var spinDirX = [-1.0, 1.0].randomElement()!
    @State var spinDirZ = [-1.0, 1.0].randomElement()!
    @State var xSpeed = Double.random(in: 0.501...2.201)
    @State var zSpeed = Double.random(in: 0.501...2.201)
    
    var body: some View {
        shape
            .foregroundColor(color)
            .rotation3DEffect(.degrees(move ? 360 : 0), axis: (x: spinDirX, y: 0, z: 0))
            .animation(Animation.linear(duration: xSpeed).repeatForever(), value: move)
            .rotation3DEffect(.degrees(move ? 360 : 0), axis: (x: 0, y: 0, z: spinDirZ), anchor: UnitPoint(x: anchor, y: anchor))
            .animation(Animation.linear(duration: zSpeed).repeatForever(), value: move)
            .onAppear {
                move = true
            }
    }
}

struct ConfettiTapPayload {
    let tapX: CGFloat
    let tapY: CGFloat
}

let confettiTapPipe = PassthroughSubject<ConfettiTapPayload, Never>()

struct CelebrationConfettiButtonStyle: ButtonStyle {
    @State var tapX: CGFloat = 0
    @State var tapY: CGFloat = 0
    @State var tapCount = 0
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .padding()
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: .infinity, style: .continuous)
                            .foregroundStyle(.red)
                            .opacity(0.26)
                        RoundedRectangle(cornerRadius: .infinity, style: .continuous)
                            .fill(Material.regular)
                        
                    }
                }
                
            ConfettiView(counter: $tapCount)
                    .opacity(tapCount == 0 ? 0 : 1)
                    .position(x: tapX, y: tapY)
                    .onReceive(confettiTapPipe, perform: { payload in
                        tapX = payload.tapX
                        tapY = payload.tapY
                        tapCount += 1
                    })
        }
            
    }
}

typealias theCongratulateButton = CelebrationConfettiButtonStyle

#Preview("🎉") {
    Button(action: { print("Pressed") }) {
        Label("Press Me", systemImage: "star")
    }
    .buttonStyle(CelebrationConfettiButtonStyle())
}

extension View {
    func celebrateTapPosition(
        dismissAfter: Double = 3.5,
        onComplete: @escaping () -> Void = {}
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { dragGesture in
                let tapX = dragGesture.location.x
                let tapY = dragGesture.location.y
                confettiTapPipe.send(ConfettiTapPayload(tapX: tapX, tapY: tapY))
                DispatchAfter(after: dismissAfter) {
                    onComplete()
                }
            }
    }
}

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
