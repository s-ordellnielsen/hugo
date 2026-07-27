import SwiftData
import SwiftUI

extension ModelContainer {
    @MainActor
    static var preview: ModelContainer {
        do {
            let container = try ModelContainerFactory.makeInMemoryContainer()
            let context = container.mainContext
            let field = Tracker(name: "Field Service", isDefault: true, iconName: "figure.walk")
            let phone = Tracker(name: "Phone Service", iconName: "phone.fill")
            context.insert(field)
            context.insert(phone)
            context.insert(Entry(date: .now.addingTimeInterval(-86_400), duration: 3_600, tracker: field))
            context.insert(Entry(date: .now, duration: 7_200, tracker: phone))
            try context.save()
            return container
        } catch { fatalError("Failed to create preview container: \(error)") }
    }
}
