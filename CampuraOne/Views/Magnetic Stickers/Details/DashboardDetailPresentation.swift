import SwiftUI

enum DashboardDetailChrome {
    static let controlsWidth: CGFloat = 52
}

/// Details opt into the standard scrolling presentation or supply their own layout.
protocol DashboardDetailContent: View {
    static var tileDescriptor: DashboardTileDescriptor { get }
    associatedtype Presentation: View
    @ViewBuilder func dashboardPresentation(in context: DashboardDetailContext) -> Presentation
}

extension DashboardDetailContent {
    func dashboardPresentation(in context: DashboardDetailContext) -> some View {
        DashboardScrollableDetail(context: context) {
            self
        }
    }
}

/// Only the heterogeneous presentation boundary uses type erasure.
struct SelectedDashboardDetail {
    let descriptor: DashboardTileDescriptor
    private let render: (DashboardDetailContext) -> AnyView

    var id: String { descriptor.id }
    var title: String { descriptor.title }

    init<Detail: DashboardDetailContent>(_ detail: Detail) {
        descriptor = Detail.tileDescriptor
        render = { context in
            AnyView(detail.dashboardPresentation(in: context))
        }
    }

    func presentation(in context: DashboardDetailContext) -> some View {
        render(context)
    }
}

struct DashboardDetailContext {
    let descriptor: DashboardTileDescriptor
    let namespace: Namespace.ID
    let safeAreaInsets: EdgeInsets
    let controls: AnyView
}

struct DashboardDetailTitle: View {
    let context: DashboardDetailContext

    var body: some View {
        Text(context.descriptor.title)
            .font(.system(size: 40, weight: .bold))
            .matchedGeometryEffect(id: "\(context.descriptor.id)-title", in: context.namespace, properties: .position)
    }
}

struct DashboardScrollableDetail<Content: View>: View {
    let context: DashboardDetailContext
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                content
            }
        }
        .padding(16)
        .padding(.vertical, screen.height / 16)
    }

    private var header: some View {
        HStack(alignment: .top) {
            if !context.descriptor.systemImage.isEmpty {
                Image(systemName: context.descriptor.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .matchedGeometryEffect(id: "\(context.descriptor.id)-icon", in: context.namespace, properties: .frame)
            }
            if !context.descriptor.title.isEmpty {
                DashboardDetailTitle(context: context)
            }
            Spacer(minLength: 12)
            context.controls
        }
    }
}
