import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UserDefaultsKeys.publisherStatus) var publisherStatus = ""

    private static var testFlightURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TestFlightURL") as? String,
            let url = URL(string: value),
            url.scheme == "https",
            !value.contains("REPLACE_WITH_INVITE_CODE")
        else {
            return nil
        }
        return url
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: PublisherStatusSelectionView()) {
                        Label {
                            Text("account.group.main.item.publisher.status")
                            Text(
                                PublisherStatus.status(for: publisherStatus)?
                                    .nameKey
                                    ?? "account.group.main.item.publisher.status.empty"
                            )
                        } icon: {
                            Image(
                                systemName: publisherStatus != ""
                                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        }
                    }
                }

                Section {
                    NavigationLink(destination: ReportSettingsView()) {
                        Label("settings.group.settings.report", systemImage: "doc.text")
                    }
                    NavigationLink(destination: CategorySettingsView()) {
                        Label("settings.group.settings.category", systemImage: "square.grid.2x2")
                    }
                    NavigationLink(destination: GeneralSettingsView()) {
                        Label("settings.group.settings.general", systemImage: "gearshape")
                    }
                }
				
				if let testFlightURL = Self.testFlightURL {
					Section {
						ShareLink(item: testFlightURL) {
							Label("settings.account.shareTestFlight", systemImage: "person.crop.circle.badge.plus")
						}
					} footer: {
						Text("settings.account.shareTestFlight.description")
					}
				}

                Section {
                    NavigationLink(destination: DebugSettingsView()) {
                        Label("debug.title", systemImage: "ant.fill")
                            .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("debug.disclaimer")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(.preview)
}
