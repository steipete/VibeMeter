import SwiftUI

extension CostTableView {
    /// Explicit view state representation for better state management
    enum ViewState {
        case loading
        case empty
        case loaded(providers: [ServiceProvider])
        case error(String)
        
        init(from spendingData: MultiProviderSpendingData) {
            let providers = spendingData.providersWithData
            
            if providers.isEmpty {
                self = .empty
            } else if providers.contains(where: { provider in
                if let data = spendingData.getSpendingData(for: provider) {
                    return data.connectionStatus == .connecting || data.connectionStatus == .syncing
                }
                return false
            }) {
                self = .loading
            } else {
                self = .loaded(providers: providers)
            }
        }
    }
}