import SwiftUI
import SwiftData

/// "Settings" tab — maps to DEFAULT_SETTINGS from background.js.
struct SettingsView: View {
    let onTriggerQuiz: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var settingsQuery: [AppSettings]

    private var s: AppSettings? { settingsQuery.first }

    var body: some View {
        if let settings = s {
            Form {
                quizSection(settings)
                answerSection(settings)
                quotaSection(settings)
                practiceSection()
            }
            .formStyle(.grouped)
        } else {
            ProgressView("Loading…")
        }
    }

    // MARK: - Form sections

    @ViewBuilder
    private func quizSection(_ s: AppSettings) -> some View {
        Section("Quiz") {
            Toggle("Enable Learning", isOn: binding(s, \.isEnabled, reschedule: true))

            Picker("Interval", selection: binding(s, \.intervalMinutes, reschedule: true)) {
                Text("1 min").tag(1)
                Text("5 min").tag(5)
                Text("10 min").tag(10)
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("60 min").tag(60)
            }
            .disabled(!s.isEnabled)

            Stepper(
                "Words per session: \(s.wordsPerPopup)",
                value: binding(s, \.wordsPerPopup),
                in: 1...5
            )
        }
    }

    @ViewBuilder
    private func answerSection(_ s: AppSettings) -> some View {
        Section("Answer Style") {
            Picker("Answer Type", selection: binding(s, \.answerType)) {
                Text("Multiple Choice").tag("choice")
                Text("Typing").tag("typing")
                Text("Mixed").tag("mixed")
            }

            Picker("Direction", selection: binding(s, \.questionDirection)) {
                Text("EN → VN").tag("en-to-vn")
                Text("VN → EN").tag("vn-to-en")
                Text("Mixed").tag("mixed")
            }
        }
    }

    @ViewBuilder
    private func quotaSection(_ s: AppSettings) -> some View {
        Section("Daily Quota") {
            Stepper(
                "New words/day: \(s.wordsPerDay)",
                value: binding(s, \.wordsPerDay),
                in: 1...20
            )
        }
    }

    @ViewBuilder
    private func practiceSection() -> some View {
        Section("Practice") {
            Button {
                onTriggerQuiz()
            } label: {
                Label("Practice Now", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    /// Creates a Binding that saves context on every change.
    private func binding<T>(
        _ settings: AppSettings,
        _ keyPath: ReferenceWritableKeyPath<AppSettings, T>,
        reschedule: Bool = false
    ) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                try? context.save()
                if reschedule { updateScheduler(settings) }
            }
        )
    }

    private func updateScheduler(_ settings: AppSettings) {
        if settings.isEnabled {
            QuizScheduler.shared.updateInterval(settings.effectiveIntervalSeconds)
        } else {
            QuizScheduler.shared.stop()
        }
    }
}
