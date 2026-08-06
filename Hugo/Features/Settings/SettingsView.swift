import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UserDefaultsKeys.publisherStatus) var publisherStatus = ""
    @AppStorage(UserDefaultsKeys.defaultRoundingRule) private var defaultRoundingRule = ""
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""
    @AppStorage(UserDefaultsKeys.overseerGreetingTemplate) private var greetingTemplate = ""

    private var currentRoundingRule: RoundingRule {
        RoundingRule(rawValue: defaultRoundingRule) ?? .up
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
                            Image(systemName: "circle.badge.checkmark.fill")
                        }
                    }
                }

                Section {
                    Picker("settings.duration.minute-interval", selection: $durationMinuteInterval) {
                        Text("1").tag(1)
                        Text("5").tag(5)
                        Text("15").tag(15)
                    }
                    Picker(selection: $defaultRoundingRule) {
                        ForEach(RoundingRule.allCases) { rule in
                            Text(rule.localizedName).tag(rule.rawValue)
                        }
                    } label: {
                        Label {
                            Text("settings.report.rounding-rule")
                            Text(currentRoundingRule.localizedName)
                        } icon: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                    .pickerStyle(.navigationLink)

                    NavigationLink(destination: OverseerSettingsView()) {
                        Label {
                            Text("settings.report.overseer")
                            Text(
                                overseerFullName.isEmpty
                                    ? String(localized: "report.overseer.empty")
                                    : overseerFullName)
                        } icon: {
                            Image(systemName: "person.crop.circle")
                        }
                    }

                    NavigationLink(destination: GreetingTemplateView()) {
                        Label {
                            Text("settings.report.greeting")
                            Text(
                                greetingTemplate.isEmpty
                                    ? String(localized: "report.greeting.default")
                                    : greetingTemplate
                            )
                            .lineLimit(1)
                        } icon: {
                            Image(systemName: "text.quote")
                        }
                    }
                } header: {
                    Text("settings.group.report")
                }

                Section {
                    NavigationLink(destination: CategoryListView()) {
                        Label("settings.link.trackers", systemImage: "chart.line.text.clipboard.fill")
                    }
                } footer: {
                    Text("settings.group.trackers.description")
                }
                Section {
                    NavigationLink(destination: DebugSettingsView()) {
                        Label("debug.title", systemImage: "ant.fill")
                            .foregroundStyle(.red)
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
            .tint(.primary)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(.preview)
}
