import Foundation

struct DefaultCategoryDefinition: Identifiable, Sendable {
    let id: UUID
    let nameKey: LocalizedStringResource
    let iconName: String
    let hue: Double
    let saturation: Double
    let brightness: Double
    let isDefault: Bool

    static let all: [DefaultCategoryDefinition] = [
        DefaultCategoryDefinition(
            id: UUID(uuidString: "A5B8A6FE-0DA4-4F7F-A9F3-2E2ACB5AA001")!,
            nameKey: "tracker.fieldservice.name",
            iconName: "figure.walk",
            hue: 0.5,
            saturation: 1,
            brightness: 0,
            isDefault: true
        )
    ]
}
