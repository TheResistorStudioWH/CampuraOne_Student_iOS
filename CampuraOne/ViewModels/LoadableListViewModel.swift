//
//  LoadableListViewModel.swift
//  CampuraOne
//
//  Created by Lin Shay on 02/06/2026.
//
    
import SwiftUI
import Combine

@MainActor
final class LoadableListViewModel<Item>: ObservableObject {
    
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let loader: () async throws -> [Item]
    
    init(loader: @escaping () async throws -> [Item]) {
        self.loader = loader
    }
    
    func load() async {
        guard !isLoading else { return }
        withAnimation {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            items = try await loader()
        } catch is CancellationError {
            // Leaving a screen is not a failed request; retain the previous items.
        } catch {
            withAnimation {
                errorMessage = error.localizedDescription
                print("列表加载失败：\(error)")
            }
            
        }
        withAnimation {
            isLoading = false
        }
        
    }
}
