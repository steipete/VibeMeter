import SwiftUI

/// A property wrapper that debounces state updates to reduce UI churn and improve performance.
///
/// Use this when you have rapidly changing state that causes expensive UI updates.
/// The wrapped value will only update after the specified duration has passed without new changes.
///
/// Example:
/// ```swift
/// struct MyView: View {
///     @DebouncedState(duration: .milliseconds(300))
///     private var displayedData = DataModel()
///
///     var body: some View {
///         Text(displayedData.title)
///             .onChange(of: rapidlyChangingData) { _, newValue in
///                 displayedData = newValue
///             }
///     }
/// }
/// ```
@propertyWrapper
@MainActor
public struct DebouncedState<Value> {
    private var storage: Storage<Value>
    
    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.updateDebounced(newValue) }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { storage.value },
            set: { storage.updateDebounced($0) }
        )
    }
    
    /// Initialize with a default value and optional debounce duration
    /// - Parameters:
    ///   - wrappedValue: The initial value
    ///   - duration: How long to wait before applying updates (default: 300ms)
    public init(wrappedValue: Value, duration: Duration = .milliseconds(300)) {
        self.storage = Storage(initialValue: wrappedValue, duration: duration)
    }
}

// MARK: - Storage

@MainActor
private final class Storage<Value>: ObservableObject {
    @Published var value: Value
    private var updateTask: Task<Void, Never>?
    private let duration: Duration
    
    init(initialValue: Value, duration: Duration) {
        self.value = initialValue
        self.duration = duration
    }
    
    func updateDebounced(_ newValue: Value) {
        updateTask?.cancel()
        updateTask = Task { [weak self, duration] in
            do {
                try await Task.sleep(for: duration)
                await MainActor.run { [weak self] in
                    self?.value = newValue
                }
            } catch {
                // Task was cancelled, ignore
            }
        }
    }
}

// MARK: - View Modifier Alternative

/// A view modifier that provides debounced updates for any value
public struct DebouncedModifier<Value: Equatable & Sendable>: ViewModifier {
    let source: Value
    let duration: Duration
    @Binding var destination: Value
    @State private var updateTask: Task<Void, Never>?
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: source) { _, newValue in
                updateTask?.cancel()
                updateTask = Task {
                    do {
                        try await Task.sleep(for: duration)
                        await MainActor.run {
                            destination = newValue
                        }
                    } catch {
                        // Cancelled
                    }
                }
            }
    }
}

public extension View {
    /// Debounces updates from a source value to a destination binding
    /// - Parameters:
    ///   - source: The rapidly changing value to monitor
    ///   - duration: How long to wait before updating
    ///   - destination: Where to store the debounced value
    func debounced<Value: Equatable & Sendable>(
        _ source: Value,
        duration: Duration = .milliseconds(300),
        to destination: Binding<Value>
    ) -> some View {
        modifier(DebouncedModifier(
            source: source,
            duration: duration,
            destination: destination
        ))
    }
}

// MARK: - Convenience Extensions

public extension View {
    /// Apply debounced updates within an onChange modifier
    /// - Parameters:
    ///   - value: The value to monitor for changes
    ///   - duration: Debounce duration
    ///   - action: Action to perform after debouncing
    func onChangeDebounced<Value: Equatable & Sendable>(
        of value: Value,
        duration: Duration = .milliseconds(300),
        perform action: @escaping (Value) -> Void
    ) -> some View {
        self
            .onChange(of: value) { _, _ in }  // Ensure onChange infrastructure is set up
            .modifier(DebouncedChangeModifier(
                value: value,
                duration: duration,
                action: action
            ))
    }
}

private struct DebouncedChangeModifier<Value: Equatable & Sendable>: ViewModifier {
    let value: Value
    let duration: Duration
    let action: (Value) -> Void
    
    @State private var updateTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, newValue in
                updateTask?.cancel()
                updateTask = Task {
                    do {
                        try await Task.sleep(for: duration)
                        await MainActor.run {
                            action(newValue)
                        }
                    } catch {
                        // Cancelled
                    }
                }
            }
    }
}

// MARK: - Optional Support

public extension DebouncedState where Value: ExpressibleByNilLiteral {
    /// Initialize with nil as the default value
    /// - Parameter duration: How long to wait before applying updates (default: 300ms)
    init(duration: Duration = .milliseconds(300)) {
        self.init(wrappedValue: nil, duration: duration)
    }
}

// MARK: - Advanced: Multiple Values

/// Debounces multiple related values as a group
@MainActor
public final class DebouncedGroup<Model>: ObservableObject {
    @Published public private(set) var model: Model
    private var updateTask: Task<Void, Never>?
    private let duration: Duration
    
    public init(initialModel: Model, duration: Duration = .milliseconds(300)) {
        self.model = initialModel
        self.duration = duration
    }
    
    public func update(_ newModel: Model) {
        updateTask?.cancel()
        updateTask = Task { [weak self, duration] in
            do {
                try await Task.sleep(for: duration)
                await MainActor.run { [weak self] in
                    self?.model = newModel
                }
            } catch {
                // Cancelled
            }
        }
    }
    
    public func update<T>(keyPath: WritableKeyPath<Model, T>, value: T) {
        var newModel = model
        newModel[keyPath: keyPath] = value
        update(newModel)
    }
}