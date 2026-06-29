//
//  MainShopListViewModel.swift
//  CampuraOne
//
//  Created by LShayc1own on 27/05/2026.
//


import Foundation
import SwiftUI
import Combine


struct MainShopListView: View {
    
    @StateObject private var vm = LoadableListViewModel<MainShop> {
        try await RemoteDataService.shared.fetchMainShops(schoolID: 1)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("正在加载商户...")
                } else if let errorMessage = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text("加载失败")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("重新加载")
                            .beButton {
                                Task {
                                    await vm.load()
                                }
                            }
                    }
                    .padding()
                } else {
                    List(vm.items) { shop in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(shop.shopName)
                                .font(.headline)
                            
                            if let address = shop.shopAddress {
                                Text(address.joined(separator: " "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("商户")
            .task {
                await vm.load()
            }
        }
    }
}

#Preview("MainShopListView") {
    MainShopListView()
}

