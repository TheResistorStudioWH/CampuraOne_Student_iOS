import SwiftUI
import PetaToolKit
import PetaKitUIX

/// A Messages-style pile shared by the small tile and the wide banner.
/// Swiping browses the pile in place; tapping opens the full-screen photo browser.
struct AdvertisementPhotoStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let advertisements: [Advertisement]
    let aspectRatio: CGFloat

    @State private var deck = AdvertisementDeck()
    @State private var dragOffset: CGFloat = 0
    @State private var isBrowsing = false
    @State private var isHorizontalDrag = false
    @State private var showingViewer = false
    @State private var departingID: Int?
    @State private var departingOffset: CGFloat = 0
    @State private var isReturningCard = false
    @State private var turnToken: UUID?

    private var ids: [Int] { advertisements.map(\.adID) }
    private var selectedIndex: Int {
        guard let selectedID = deck.ids.first, let index = ids.firstIndex(of: selectedID) else { return 0 }
        return index
    }
    private var visibleAds: [Advertisement] {
        var visibleIDs = Array(deck.ids.prefix(3))
        if dragOffset > 0, let last = deck.ids.last, !visibleIDs.contains(last) {
            visibleIDs.append(last)
        }
        if let departingID, !visibleIDs.contains(departingID) {
            visibleIDs.append(departingID)
        }
        let available = Dictionary(advertisements.map { ($0.adID, $0) }, uniquingKeysWith: { first, _ in first })
        return visibleIDs.compactMap { available[$0] }
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
                    let leaving = departingID == advertisement.adID
                    let relative = depth(for: advertisement.adID)
                    let displayDepth = leaving && !isReturningCard ? 0 : relative
                    photoCard(advertisement, size: cardSize)
                        .scaleEffect(0.94 + CGFloat(min(displayDepth, 2)) * 0.025)
                        .rotationEffect(.degrees(displayDepth == 0 ? 0 : (displayDepth == 1 ? -4.5 : 4.5)))
                        .offset(x: leaving && !isReturningCard ? departingOffset : horizontalOffset(relative: relative),
                                y: CGFloat(displayDepth) * -4)
                        .zIndex(leaving ? (isReturningCard ? 0 : 5) : (relative == 0 ? 4 : Double(3 - relative)))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: size.width, height: size.height)
            // Keep offscreen pages hidden, but leave room for every card's shadow.
            .clipShape(Rectangle().inset(by: -shadowOutset))
            .contentShape(Rectangle())
            .onTapGesture {
                guard turnToken == nil else { return }
                showingViewer = true
            }
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
            AdvertisementPhotoViewer(advertisements: advertisements, initialID: deck.ids.first ?? ids.first)
        }
        .onChange(of: ids, initial: true) { _, newIDs in
            resetMotion()
            deck.synchronize(with: newIDs)
            if newIDs.isEmpty { showingViewer = false }
        }
        .onDisappear { resetMotion() }
        .sensoryFeedback(.selection, trigger: deck.ids.first)
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

    private func depth(for id: Int) -> Int {
        if dragOffset > 0, id == deck.ids.last, id != deck.ids.first { return 1 }
        return min(3, deck.ids.firstIndex(of: id) ?? 3)
    }

    private func horizontalOffset(relative: Int) -> CGFloat {
        relative == 0 ? dragOffset : (dragOffset > 0 && relative == 1 ? 0 : CGFloat(relative) * 3)
    }

    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard deck.ids.count > 1, turnToken == nil else { return }
                if !isBrowsing {
                    isBrowsing = true
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                defer {
                    isBrowsing = false
                    isHorizontalDrag = false
                }
                guard isHorizontalDrag, deck.ids.count > 1, turnToken == nil else { return }
                let projected = value.predictedEndTranslation.width
                let threshold = max(35, width * 0.18)
                let step = projected < 0 ? 1 : -1
                if abs(projected) > threshold {
                    advance(by: step, width: width)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { dragOffset = 0 }
                }
            }
    }

    private func advance(by step: Int, width: CGFloat? = nil) {
        guard deck.ids.count > 1, turnToken == nil else { return }
        guard let width, !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.15)) {
                deck.advance(by: step)
                dragOffset = 0
            }
            return
        }

        let token = UUID()
        turnToken = token
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            departingID = deck.ids.first
            departingOffset = dragOffset
            isReturningCard = false
            deck.advance(by: step)
            dragOffset = 0
        }
        // The departing card leaves above the pile, then returns underneath it.
        withAnimation(.easeOut(duration: 0.17), completionCriteria: .removed) {
            departingOffset = (step > 0 ? -1 : 1) * (width + 48)
        } completion: {
            guard turnToken == token else { return }
            withAnimation(.smooth(duration: 0.22), completionCriteria: .removed) {
                isReturningCard = true
                departingOffset = 0
            } completion: {
                guard turnToken == token else { return }
                resetMotion()
            }
        }
    }

    private func resetMotion() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            turnToken = nil
            departingID = nil
            departingOffset = 0
            dragOffset = 0
            isReturningCard = false
            isBrowsing = false
            isHorizontalDrag = false
        }
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
                Image(systemName: showsGrid ? "rectangle.stack" : "square.grid.2x2")
                    .beButton { showsGrid.toggle() }
                Spacer()
                Text("\(ids.count) 张图片")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("完成").beButton { dismiss() }
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
            .shadow(color: .black.opacity(.colorScheme(light: 0.24, dark: 0.48, colorScheme)), radius: 10, x: 0, y: 6)
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}
