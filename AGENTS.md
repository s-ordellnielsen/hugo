# Agent Instructions: Hugo – Helping You Go Out

This file contains strict context, architectural constraints, and modern coding standards for AI agents working in this repository.

## 1. System Target & Tech Stack
- **Platform Target:** iOS 26+ / iPadOS 26+ (No legacy fallbacks allowed).
- **Language:** Swift 6+ with strict concurrency checked.
- **UI Framework:** SwiftUI exclusively (No UIKit wrapper components unless absolutely unavoidable).
- **Database & Sync:** SwiftData with CloudKit container integration (requires automatic syncing constraints).
- **Concurrency:** Modern structured concurrency (`Task`, `actor`, `async/await`, `@MainActor`).

---

## 2. Architecture & Design Patterns

### View & Model Separation
- Keep Views purely visual. Do not perform complex data mapping, computation, or database queries inside the View body.
- Isolate state and business logic into `@MainActor` classes decorated with the `@Observable` macro.
- Use **SwiftData Model Context** dynamically injected via the environment rather than singleton databases.

### Concurrency Rules (Swift 6 Strict Mode)
- Never use legacy threading structures like `DispatchQueue.main.async` or `NSThread`. Use `MainActor.run` or mark classes/methods with `@MainActor`.
- Avoid unstructured `Task { ... }` where structural `async let` or `taskGroup` can be used.
- Ensure all models passing between threads conform to `Sendable` or are constrained to the `@MainActor`.

---

## 3. SwiftUI & State Guidelines

### State Management
- Use the modern `@Observable` macro for ViewModels and State Containers.
- Use `@State` inside views to hold locally instantiated `@Observable` objects or primitive local state.
- Use `@Bindable` when you need to create bindings (`$`) to properties of an `@Observable` model object.
- Never use legacy property wrappers: `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject`.

```swift
/// PREFERRED PATTERN
import SwiftUI

@Observable
@MainActor
class FeatureViewModel {
    var searchQueries: String = ""
    var isProcessing = false
    
    func performSearch() async {
        isProcessing = true
        defer { isProcessing = false }
        // Fetch logic...
    }
}

struct FeatureView: View {
    @State private var viewModel = FeatureViewModel()
    
    var body: some View {
        VStack {
            TextField("Search...", text: $viewModel.searchQueries)
            
            if viewModel.isProcessing {
                ProgressView()
            } else {
                Button("Search") {
                    Task { await viewModel.performSearch() }
                }
            }
        }
    }
}
```

## 4. Previews

```swift
/// PREFERRED PATTERN FOR PREVIEWS
#Preview {
    ReportView()
        .modelContainer(.preview)
}
```

## 5. Domain Vocabulary & Business Logic

### Theocratic Year Definition
In this application, we use a custom calendar system called the **Theocratic Year**. You must respect this definition across all date calculations, database schemas, and UI layouts.

- **Definition:** A theocratic year runs from **September 1st** of one year to **August 31st** of the following year.
- **Naming Convention:** It must always be formatted and referred to as `YYYY/YYYY` (e.g., September 1, 2026, to August 31, 2027, is designated as `2026/2027`).
- **Calculations:** 
  - When calculating statistical totals, charts, or filtering database records for a "theocratic year", always bound your start date to September 1st and end date to August 31st.

#### Swift helper implementation reference:
If you need to calculate or group items by a theocratic year, use or implement a helper like this:

```swift
extension Date {
    /// Returns the theocratic year string (e.g., "2026/2027") for the date.
    var theocraticYearString: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: self)
        let month = calendar.component(.month, from: self)
        
        if month >= 9 {
            return "\(year)/\(year + 1)"
        } else {
            return "\(year - 1)/\(year)"
        }
    }
}
