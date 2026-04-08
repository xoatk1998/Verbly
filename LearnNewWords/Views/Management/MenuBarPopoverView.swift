import SwiftUI

/// Root view of the NSPopover attached to the menu bar status item.
/// Four tabs mirroring the Chrome extension popup.
struct MenuBarPopoverView: View {
    /// Called when the user taps "Practice Now" in Settings.
    let onTriggerQuiz: () -> Void

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Words").tag(0)
                Text("All Words").tag(1)
                Text("Stats").tag(2)
                Text("Settings").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(10)

            Divider()

            Group {
                switch selectedTab {
                case 0:  WordsListView()
                case 1:  AllWordsView()
                case 2:  StatsView()
                case 3:  SettingsView(onTriggerQuiz: onTriggerQuiz)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 380, height: 520)
    }
}
