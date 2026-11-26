import SwiftUI

/// Explains the state of iCloud sync on this device and what to do about it.
struct CloudSyncStatusView: View {
    @Environment(CloudSyncMonitor.self) private var monitor: CloudSyncMonitor?

    private var status: CloudSyncStatus { monitor?.status ?? .upToDate(lastSync: nil) }

    var body: some View {
        List {
            Section {
                Label {
                    Text(status.title).font(.headline)
                } icon: {
                    Image(systemName: status.symbolName)
                }
                Text(status.message)
            } footer: {
                if let lastSuccess = monitor?.lastSuccess {
                    Text("settings.sync.lastSync.\(lastSuccess.formatted(.relative(presentation: .named)))")
                } else {
                    Text("settings.sync.lastSync.never")
                }
            }
        }
        .readableListWidth()
        .editorialNavigationTitle("settings.sync.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await monitor?.refreshAccount() }
    }
}

#Preview {
    NavigationStack {
        CloudSyncStatusView()
    }
    .environment(CloudSyncMonitor(readAccount: { .available }))
}
