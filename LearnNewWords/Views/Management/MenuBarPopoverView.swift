import SwiftUI

/// Root view of the NSPopover — icon tab bar + content pane.
struct MenuBarPopoverView: View {
    let onTriggerQuiz: () -> Void
    @State private var selectedTab = 0
    private let teal = Color(red: 0.05, green: 0.58, blue: 0.53)

    private let tabs: [(icon: String, label: String)] = [
        ("calendar.badge.clock", "Today"),
        ("text.book.closed",     "Library"),
        ("chart.bar.fill",       "Stats"),
        ("gearshape.fill",       "Settings"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabContent
            Divider()
            tabBar
        }
        .frame(width: 380, height: 540)
        .background(Color.clear.background(.regularMaterial))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(teal)
                .font(.title3)
            Text("Verbly")
                .font(.headline)
                // .primary adapts: black in light, white in dark
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
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

    // MARK: - Icon tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = i }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tabs[i].icon)
                            .font(.system(size: 18, weight: selectedTab == i ? .semibold : .regular))
                        Text(tabs[i].label)
                            .font(.system(size: 10, weight: selectedTab == i ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == i ? teal : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == i ? teal.opacity(0.1) : Color.clear
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
