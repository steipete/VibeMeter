Here is the content from the Apple Developer documentation page "Migrating from the Observable Object protocol to the Observable macro" converted to Markdown format.

# Migrating from the Observable Object protocol to the Observable macro

Update your existing app to leverage the benefits of Observation in Swift.

***

## Overview

Starting with iOS 17, iPadOS 17, macOS 14, tvOS 17, and watchOS 10, SwiftUI provides support for Observation, a Swift-specific implementation of the observer design pattern. Adopting Observation provides your app with the following benefits:

> *   Tracking optionals and collections of objects, which isn't possible when using `ObservableObject`.
> *   Using existing data flow primitives like `State` and `Environment` instead of object-based equivalents such as `StateObject` and `EnvironmentObject`.
> *   Updating views based on changes to the observable properties that a view's body reads instead of any property changes that occur to an observable object, which can help improve your app's performance.

To take advantage of these benefits in your app, you'll discover how to replace existing source code that relies on `ObservableObject` with code that leverages the `@Observable()` macro.

***

## Use the Observable macro

To adopt Observation in an existing app, begin by replacing `ObservableObject` in your data model type with the `@Observable()` macro. The `@Observable()` macro generates source code at compile time that adds observation support to the type.

**BEFORE**
```swift
// BEFORE
import SwiftUI

class Library: ObservableObject {
    // ...
}
```

**AFTER**
```swift
// AFTER
import SwiftUI

@Observable
class Library {
    // ...
}
```

Then remove the `@Published` property wrapper from observable properties. Observation doesn't require a property wrapper to make a property observable. Instead, the accessibility of the property in relationship to an observer, such as a view, determines whether a property is observable.

**BEFORE**
```swift
// BEFORE
@Observable
class Library {
    @Published var books: [Book] = [Book(), Book(), Book()]
}
```

**AFTER**
```swift
// AFTER
@Observable
class Library {
    var books: [Book] = [Book(), Book(), Book()]
}
```

If you have properties that are accessible to an observer that you don't want to track, apply the `@ObservationIgnored()` macro to the property.

***

## Migrate incrementally

You don't need to make a wholesale replacement of the `ObservableObject` protocol throughout your app. Instead, you can make changes incrementally. Start by changing one data model type to use the `@Observable()` macro. Your app can mix data model types that use different observation systems. However, SwiftUI tracks changes differently based on the observation system that a data model type uses, `Observable` versus `ObservableObject`.

You may notice slight behavioral differences in your app based on the tracking method. For instance, when tracking as `@Observable()`, SwiftUI updates a view only when an observable property changes and the view's body reads the property directly. The view doesn't update when observable properties not read by body changes. In contrast, a view updates when any published property of an `ObservableObject` instance changes, even if the view doesn't read the property that changes, when tracking as `ObservableObject`.

> **Note:** To learn more about when SwiftUI updates views when observable properties change, see [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data).

***

## Migrate other source code

After applying the `@Observable()` macro, you can update your data flow primitives. Although `StateObject` and `EnvironmentObject` support types using the `@Observable()` macro for incremental migration, you should replace them with `State` and `Environment` to fully adopt Observation.

**BEFORE**
```swift
// BEFORE
@main
struct BookReaderApp: App {
    @StateObject private var library = Library()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
        }
    }
}
```

**AFTER**
```swift
// AFTER
@main
struct BookReaderApp: App {
    @State private var library = Library()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
        }
    }
}
```

Similarly, replace `@EnvironmentObject` with the `@Environment` property wrapper.

**BEFORE**
```swift
// BEFORE
struct LibraryView: View {
    @EnvironmentObject var library: Library

    var body: some View {
        List(library.books) { book in
            BookView(book: book)
        }
    }
}
```

**AFTER**
```swift
// AFTER
struct LibraryView: View {
    @Environment(Library.self) private var library

    var body: some View {
        List(library.books) { book in
            BookView(book: book)
        }
    }
}
```

***

## Remove the ObservedObject property wrapper

To complete the migration, change other data model types to support Observation by replacing `ObservableObject` with the `@Observable()` macro and removing `@Published`.

**BEFORE**
```swift
// BEFORE
class Book: ObservableObject, Identifiable {
    @Published var title = "Sample Book Title"
    let id = UUID() // A unique identifier that never changes.
}
```

**AFTER**
```swift
// AFTER
@Observable
class Book: Identifiable {
    var title = "Sample Book Title"
    let id = UUID() // A unique identifier that never changes.
}
```

Next, remove the `@ObservedObject` property wrapper. SwiftUI automatically tracks any observable properties that a view's body reads directly.

**BEFORE**
```swift
// BEFORE
struct BookView: View {
    @ObservedObject var book: Book
    @State private var isEditorPresented = false

    var body: some View {
        HStack {
            Text(book.title)
            Spacer()
            Button("Edit") {
                isEditorPresented = true
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            BookEditView(book: book)
        }
    }
}
```

**AFTER**
```swift
// AFTER
struct BookView: View {
    var book: Book
    @State private var isEditorPresented = false

    var body: some View {
        HStack {
            Text(book.title)
            Spacer()
            Button("Edit") {
                isEditorPresented = true
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            BookEditView(book: book)
        }
    }
}
```

If a view needs a binding to an observable type, replace `@ObservedObject` with the `@Bindable` property wrapper.

**BEFORE**
```swift
// BEFORE
struct BookEditView: View {
    @ObservedObject var book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack() {
            TextField("Title", text: $book.title)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    dismiss()
                }
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

**AFTER**
```swift
// AFTER
struct BookEditView: View {
    @Bindable var book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack() {
            TextField("Title", text: $book.title)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    dismiss()
                }
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```