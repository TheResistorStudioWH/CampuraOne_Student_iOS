//
//  AD_LargeBanner.swift
//  CampuraOne
//
//  Created by Lin Shay on 06/06/2026.
//

import SwiftUI
import SwiftData
import PagingView

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

struct AD_LargeBanner: View {
    let advertisements: [Advertisement]
    @State private var selection: Int?
    
    private var activeLargeAdvertisements: [Advertisement] {
        advertisements.activeLargeAdvertisements()
    }
    
    init(advertisements: [Advertisement]) {
        self.advertisements = advertisements
        _selection = State(initialValue: advertisements.activeLargeAdvertisements().first?.adID)
    }
    
    var body: some View {
        Group {
            if advertisements.isEmpty {
                placeholder
            } else {
                TabView(selection: $selection) {
                    ForEach(advertisements) { advertisement in
                        RemoteImageView(
                            url: advertisement.imageURL,
                            cacheKey: advertisement.imageCacheKey,
                            contentMode: .fit,
                            cornerRadius: 22
                        ) {
                            placeholder
                        }
                        .tag(Optional(advertisement.adID))
                    }
                }
                .frame(height: screen.width/3)
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        .padding(.horizontal)
        
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Material.bar)
            .frame(width:.infinity, height: screen.width/3)
            .overlay(alignment: .center) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        
    }
}
