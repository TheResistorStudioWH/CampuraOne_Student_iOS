import SwiftUI

/// A Messages-style pile shared by the small tile and the wide banner.
/// Swiping browses the pile in place; tapping opens the full-screen photo browser.
struct AdvertisementPhotoStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let advertisements: [Advertisement]
    let aspectRatio: CGFloat

    @State private var selectedID: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var isBrowsing = false
    @State private var isHorizontalDrag = false
    @State private var showingViewer = false

    private var ids: [Int] { advertisements.map(\.adID) }
    private var selectedIndex: Int {
        guard let selectedID, let index = ids.firstIndex(of: selectedID) else { return 0 }
        return index
    }
    private var visibleIndices: [Int] {
        guard !advertisements.isEmpty else { return [] }
        return Array(max(0, selectedIndex - 1)...min(advertisements.count - 1, selectedIndex + 2))
    }
    private var visibleAds: [Advertisement] {
        visibleIndices.map { advertisements[$0] }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let shadowOutset = min(24, min(size.width, size.height) * 0.22)
            let inset: CGFloat = advertisements.count > 1 ? 9 : 0
            let cardSize = CGSize(width: max(size.width - inset * 2, 0),
                                  height: max(size.height - inset * 2, 0))

            ZStack {
                ForEach(visibleAds) { advertisement in
                    let index = ids.firstIndex(of: advertisement.adID) ?? 0
                    let relative = index - selectedIndex
                    photoCard(advertisement, size: cardSize)
                        .scaleEffect(relative == 0 ? 0.94 : 0.94 + CGFloat(max(relative, 0)) * 0.025)
                        .rotationEffect(.degrees(relative == 0 ? 0 : (relative == 1 ? -4.5 : 4.5)))
                        .offset(x: horizontalOffset(relative: relative, width: size.width, shadowOutset: shadowOutset),
                                y: CGFloat(max(relative, 0)) * -4)
                        .zIndex(relative == 0 ? 4 : Double(3 - abs(relative)))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: size.width, height: size.height)
            // Keep offscreen pages hidden, but leave room for every card's shadow.
            .clipShape(Rectangle().inset(by: -shadowOutset))
            .contentShape(Rectangle())
            .onTapGesture { showingViewer = true }
            .simultaneousGesture(swipeGesture(width: size.width))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("广告图片叠放")
            .accessibilityValue("第 \(selectedIndex + 1) 张，共 \(advertisements.count) 张")
            .accessibilityHint("左右轻扫预览，轻点查看全部图片")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "下一张") { advance(by: 1) }
            .accessibilityAction(named: "上一张") { advance(by: -1) }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .fullScreenCover(isPresented: $showingViewer) {
            AdvertisementPhotoViewer(advertisements: advertisements, initialID: selectedID ?? ids.first)
        }
        .onChange(of: ids, initial: true) { _, newIDs in
            dragOffset = 0
            if !newIDs.contains(selectedID ?? -1) { selectedID = newIDs.first }
            if newIDs.isEmpty { showingViewer = false }
        }
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    private func photoCard(_ advertisement: Advertisement, size: CGSize) -> some View {
        AdvertisementImage(advertisement: advertisement, contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .modifier(AdvertisementPhotoShadow())
    }

    private func horizontalOffset(relative: Int, width: CGFloat, shadowOutset: CGFloat) -> CGFloat {
        switch relative {
        case -1: return dragOffset > 0 ? 0 : -width - shadowOutset * 2
        case 0: return dragOffset
        default: return CGFloat(relative) * 3
        }
    }

    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard advertisements.count > 1 else { return }
                if !isBrowsing {
                    isBrowsing = true
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag else { return }
                let atEdge = (selectedIndex == 0 && value.translation.width > 0)
                    || (selectedIndex == advertisements.count - 1 && value.translation.width < 0)
                dragOffset = value.translation.width * (atEdge ? 0.15 : 1)
            }
            .onEnded { value in
                defer {
                    isBrowsing = false
                    isHorizontalDrag = false
                }
                guard isHorizontalDrag, advertisements.count > 1 else { return }
                let projected = value.predictedEndTranslation.width
                let threshold = max(35, width * 0.18)
                let step = projected < 0 ? 1 : -1
                withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.38, dampingFraction: 0.84)) {
                    if abs(projected) > threshold, ids.indices.contains(selectedIndex + step) {
                        advance(by: step)
                    }
                    dragOffset = 0
                }
            }
    }

    private func advance(by step: Int) {
        guard advertisements.count > 1 else { return }
        selectedID = ids[min(max(selectedIndex + step, 0), advertisements.count - 1)]
    }
}

private struct AdvertisementPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let advertisements: [Advertisement]
    let initialID: Int?

    @State private var selectedID: Int?
    @State private var showsGrid = false

    private var ids: [Int] { advertisements.map(\.adID) }
    private var currentID: Int? {
        guard let selectedID, ids.contains(selectedID) else { return ids.first }
        return selectedID
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showsGrid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(advertisements) { advertisement in
                            AdvertisementImage(advertisement: advertisement, contentMode: .fill)
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                                .modifier(AdvertisementPhotoShadow())
                                .onTapGesture {
                                    selectedID = advertisement.adID
                                    showsGrid = false
                                }
                        }
                    }
                    .padding()
                }
                .padding(.top, 52)
            } else {
                TabView(selection: Binding(
                    get: { currentID },
                    set: { selectedID = $0 }
                )) {
                    ForEach(advertisements) { advertisement in
                        AdvertisementImage(advertisement: advertisement, contentMode: .fit)
                            .modifier(AdvertisementPhotoShadow())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(Optional(advertisement.adID))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    showsGrid.toggle()
                } label: {
                    Image(systemName: showsGrid ? "rectangle.stack" : "square.grid.2x2")
                }
                Spacer()
                Text("\(ids.count) 张图片")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("完成") { dismiss() }
            }
            .tint(.white)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.88))
        }
        .safeAreaInset(edge: .bottom) {
            if !showsGrid, let currentID, let index = ids.firstIndex(of: currentID) {
                Text("\(index + 1) / \(ids.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.88))
            }
        }
        .onAppear { selectedID = initialID }
        .onChange(of: ids) { _, newIDs in
            if newIDs.isEmpty { dismiss() }
            else if !newIDs.contains(selectedID ?? -1) { selectedID = newIDs.first }
        }
    }
}

private struct AdvertisementPhotoShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.48 : 0.24), radius: 10, x: 0, y: 6)
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}
