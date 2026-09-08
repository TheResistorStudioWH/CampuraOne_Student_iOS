import SwiftUI

struct LoginAnimatedSymbolCard: View {
    @State private var symbolStep = 0

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: symbolName)
                    .font(.system(size: 100, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .animation(.smooth(duration: 0.55), value: symbolStep)
                Spacer()
            }
            Spacer()
        }
        .task {
            await startSymbolLoop()
        }
    }

    private var symbolName: String {
        switch symbolStep {
        case 0: return "graduationcap.fill"
        case 1: return "person.badge.key.fill"
        case 2: return "qrcode.viewfinder"
        default: return "sparkles"
        }
    }

    @MainActor
    private func startSymbolLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) {
                symbolStep = (symbolStep + 1) % 4
            }
        }
    }
}

#Preview {
    LoginAnimatedSymbolCard()
}
