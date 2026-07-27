import SwiftData
import SwiftUI

struct DefaultCategoryButton: View {
    @Environment(\.modelContext) private var context
    @State private var errorMessage: String?

    var tracker: Tracker

    var body: some View {
        Button {
            do {
                try DefaultCategoryService(context: context).setDefault(tracker.isDefault ? nil : tracker)
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            Image(systemName: tracker.isDefault ? "star.fill" : "star")
                .foregroundStyle(tracker.isDefault ? .yellow : .primary)
                .contentTransition(.symbolEffect(.replace))
        }
        .alert("common.error", isPresented: errorAlertBinding) {
            Button("common.dismiss", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "common.error")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(tracker: Tracker(name: "Field Service"))
            .modelContainer(.preview)
    }
}
