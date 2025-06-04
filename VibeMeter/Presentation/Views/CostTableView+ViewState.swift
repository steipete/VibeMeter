import SwiftUI

extension CostTableView {
    /// Explicit view state representation for better state management
    enum ViewState: Equatable {
        case loading
        case empty
        case loaded(providers: [ServiceProvider])
        case error(String)

        @MainActor
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

// MARK: - State Views

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No Spending Data")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Connect to a provider to see spending")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)

            Text("Loading spending data...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Unable to Load Data")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
