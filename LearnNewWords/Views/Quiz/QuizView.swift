import SwiftUI
import SwiftData

/// Main quiz interface. Steps through each QuizItem in the session,
/// records answers, and dismisses when all items are answered or timeout fires.
struct QuizView: View {
    let session: [QuizItem]
    let context: ModelContext
    let stats: AppStats
    let onComplete: () -> Void
    /// Passed in directly to avoid @Query, whose SwiftData observation
    /// machinery deadlocks @MainActor during synchronous view teardown.
    let sessionTimeoutSeconds: Int?

    @State private var currentIndex = 0
    @State private var showFeedback = false
    @State private var lastCorrect = false
    @State private var isAdvancing = false
    private var currentItem: QuizItem { session[currentIndex] }

    var body: some View {
        ZStack {
            // Green overlay background fills the entire screen
            Color(red: 0.13, green: 0.70, blue: 0.37)
                .ignoresSafeArea()

            // Quiz card centered on screen
            VStack(spacing: 16) {
                headerRow
                questionBlock
                if let timeout = sessionTimeoutSeconds {
                    QuizProgressBarView(totalSeconds: timeout) {
                        advance(correct: false)
                    }
                    .id(currentIndex)  // restart timer fresh on every question
                }
                answerArea
                    .id(currentIndex)  // force new view instance → resets selected/input state
                feedbackLabel
            }
            .padding(20)
            .frame(width: 440, height: 360)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 24)
        }
        .onAppear { speakCurrentWord() }
        .onChange(of: currentIndex) { _, _ in speakCurrentWord() }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("\(currentIndex + 1) / \(session.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                // Defer to next run loop so the button action completes before
                // close() tears down the NSHostingView (crash if done inline).
                DispatchQueue.main.async { onComplete() }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var questionBlock: some View {
        VStack(spacing: 6) {
            Text(currentItem.direction == .enToVn
                 ? currentItem.word.english
                 : currentItem.word.vietnamese)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)

            Text(currentItem.direction == .enToVn ? "→ Vietnamese?" : "→ English?")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var answerArea: some View {
        if currentItem.answerMode == .choice {
            MultipleChoiceView(item: currentItem, onAnswer: advance)
        } else {
            TypingAnswerView(item: currentItem, onAnswer: advance)
        }
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if showFeedback {
            Text(lastCorrect ? "✓ Correct!" : "✗ Wrong")
                .font(.headline)
                .foregroundStyle(lastCorrect ? .green : .red)
        } else {
            // Reserve space so layout doesn't shift when feedback appears
            Text(" ").font(.headline)
        }
    }

    // MARK: - Actions

    private func advance(correct: Bool) {
        guard !isAdvancing else { return }
        isAdvancing = true

        SpacedRepetitionEngine.recordAnswer(
            word: currentItem.word,
            correct: correct,
            stats: stats,
            context: context
        )
        lastCorrect = correct
        showFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showFeedback = false
            isAdvancing = false
            if currentIndex + 1 < session.count {
                currentIndex += 1
            } else {
                onComplete()
            }
        }
    }

    private func speakCurrentWord() {
        // Speak English word aloud for EN→VN questions (wired in Phase 6)
        if currentItem.direction == .enToVn {
            SpeechService.shared.speak(currentItem.word.english)
        }
    }
}
