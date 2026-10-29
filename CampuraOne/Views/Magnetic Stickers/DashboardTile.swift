import SwiftUI
import PetaKitUIX
import PetaToolKit

struct DashboardTileDescriptor {
    let id: String
    let title: String
    let systemImage: String
}

/// Shared presentation state and opening action; each feature decides when to use it.
struct DashboardTileContext {
    let namespace: Namespace.ID
    @Binding var isOpened: Bool
    let openDetail: (SelectedDashboardDetail) -> Void

    func open<Detail: DashboardDetailContent>(_ detail: Detail) {
        withAnimation {
            isOpened = true
        }
        openDetail(SelectedDashboardDetail(detail))
    }
}

/// The common tile surface knows about actions, never about individual feature IDs.
struct DashboardTile<Content: View, ToolBar: View>: View {
    let descriptor: DashboardTileDescriptor
    let context: DashboardTileContext
    var onOpen: (() -> Void)? = nil
    var titleAction: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @ViewBuilder let toolBar: ToolBar

    var body: some View {
        if let onOpen {
            tileSurface
                .beButton(onOpen)
                .buttonStyle(.plain)
        } else {
            tileSurface
        }
    }

    private var tileSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let titleAction {
                    titleLabel
                        .beButton(titleAction)
                        .buttonStyle(.plain)
                } else {
                    titleLabel
                }
                toolBar
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(context.isOpened ? 0 : 1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Material.bar)
                .matchedGeometryEffect(id: "\(descriptor.id)-bg", in: context.namespace, properties: .frame)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 10)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var titleLabel: some View {
        HStack {
            if !descriptor.systemImage.isEmpty {
                Image(systemName: descriptor.systemImage)
                    .font(.headline)
                    .matchedGeometryEffect(id: "\(descriptor.id)-icon", in: context.namespace)
            }
            if !descriptor.title.isEmpty {
                Text(descriptor.title)
                    .font(.system(size: 20))
                    .bold()
                    .matchedGeometryEffect(id: "\(descriptor.id)-title", in: context.namespace, properties: .position)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
