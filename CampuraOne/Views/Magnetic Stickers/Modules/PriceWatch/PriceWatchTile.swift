import SwiftUI
import PetaKitUIX

struct PriceWatchTile: View {
    let context: DashboardTileContext
    @ObservedObject private var store = PriceWatchStore.shared
    var body: some View {
        DashboardTile(descriptor: PriceWatchDetailView.tileDescriptor, context: context,
                      onOpen: { context.open(PriceWatchDetailView()) }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(store.snapshot.products.count + store.snapshot.promotions.count)")
                        .font(.title.bold()).foregroundStyle(.green).monospacedDigit()
                    Text("项关注").font(.caption).foregroundStyle(.secondary)
                }
                if let latest = store.snapshot.notices.max(by: { $0.occurredAt < $1.occurredAt }) {
                    Label(latest.title, systemImage: latest.kind == .priceDrop ? "arrow.down.right" : "tag.fill")
                        .font(.caption).lineLimit(2)
                } else {
                    Text(store.snapshot.products.isEmpty && store.snapshot.promotions.isEmpty
                         ? "关注商品与活动\n把优惠留在这里" : "暂无价格变化记录")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, alignment: .leading)
        } toolBar: { EmptyView() }
    }
}
