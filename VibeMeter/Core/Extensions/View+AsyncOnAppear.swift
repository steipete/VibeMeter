import SwiftUI

extension View {
    /// Performs an async action when this view appears.
    /// - Parameter action: The async action to perform. If `action` is `nil`, the call has no effect.
    /// - Returns: A view that performs the async action when it appears.
    func onAppearAsync(perform action: (() async -> Void)? = nil) -> some View {
        onAppear {
            guard let action else { return }
            Task {
                await action()
            }
        }
    }

    /// Performs an async action when this view appears with priority.
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///   - action: The async action to perform. If `action` is `nil`, the call has no effect.
    /// - Returns: A view that performs the async action when it appears.
    func onAppearAsync(priority: TaskPriority = .userInitiated,
                       perform action: (() async -> Void)? = nil) -> some View {
        onAppear {
            guard let action else { return }
            Task(priority: priority) {
                await action()
            }
        }
    }

    /// Performs an async throwing action when this view appears.
    /// - Parameters:
    ///   - action: The async throwing action to perform.
    ///   - onError: Error handler called if the action throws.
    /// - Returns: A view that performs the async action when it appears.
    func onAppearAsync(
        perform action: @escaping () async throws -> Void,
        onError: @escaping (Error) -> Void) -> some View {
        onAppear {
            Task {
                do {
                    try await action()
                } catch {
                    onError(error)
                }
            }
        }
    }

    /// Performs an async action when this view disappears.
    /// - Parameter action: The async action to perform. If `action` is `nil`, the call has no effect.
    /// - Returns: A view that performs the async action when it disappears.
    func onDisappearAsync(perform action: (() async -> Void)? = nil) -> some View {
        onDisappear {
            guard let action else { return }
            Task {
                await action()
            }
        }
    }

    /// Performs an async action when this view appears, with automatic cancellation when it disappears.
    /// - Parameter action: The async action to perform. The task will be cancelled if the view disappears.
    /// - Returns: A view that performs the async action with lifecycle management.
    func onAppearCancellable(perform action: @escaping () async -> Void) -> some View {
        modifier(CancellableTaskModifier(action: action))
    }
}

// MARK: - Supporting Types

/// A view modifier that manages a cancellable async task tied to view lifecycle
private struct CancellableTaskModifier: ViewModifier {
    let action: () async -> Void
    @State
    private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                task = Task {
                    await action()
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }
}

// MARK: - Task Management Extensions

extension View {
    /// Performs an async action repeatedly while the view is visible.
    /// - Parameters:
    ///   - interval: The time interval between executions in seconds.
    ///   - action: The async action to perform repeatedly.
    /// - Returns: A view that performs the action repeatedly.
    @available(macOS 15.0, *)
    func onAppearRepeating(
        interval: Duration,
        perform action: @escaping () async -> Void) -> some View {
        modifier(RepeatingTaskModifier(interval: interval, action: action))
    }
}

/// A view modifier that manages a repeating async task
@available(macOS 15.0, *)
private struct RepeatingTaskModifier: ViewModifier {
    let interval: Duration
    let action: () async -> Void
    @State
    private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                task = Task {
                    while !Task.isCancelled {
                        await action()
                        do {
                            try await Task.sleep(for: interval)
                        } catch {
                            break // Task was cancelled
                        }
                    }
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }
}

// MARK: - Example Usage

/*
 Example usage:

 ```swift
 struct MyView: View {
     @State private var data: [Item] = []
     @State private var errorMessage: String?

     var body: some View {
         List(data) { item in
             Text(item.name)
         }
         .onAppearAsync {
             await loadData()
         }
         // Or with error handling:
         .onAppearAsync(
             perform: { try await loadDataThrowing() },
             onError: { error in
                 errorMessage = error.localizedDescription
             }
         )
         // Or with cancellation:
         .onAppearCancellable {
             await performLongRunningTask()
         }
         // Or repeating (macOS 15+):
         .onAppearRepeating(interval: .seconds(30)) {
             await refreshData()
         }
     }

     func loadData() async {
         // Async work here
     }
 }
 ```
 */
