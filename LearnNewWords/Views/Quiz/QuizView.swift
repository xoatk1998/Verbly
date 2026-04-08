import SwiftUI
import SwiftData

/// Main quiz interface. Steps through each QuizItem in the session,
/// records answers, then shows a review card before dismissing.
///
/// Bug fixes applied here:
///   Bug-2: Session-level countdown (no .id reset per question); expiry hides overlay.
///   Bug-3: Wrong answer → brief "try again" feedback, no auto-advance; correct → 3 s pause.
///   Bug-4: Speaker icon next to question word; VN→EN auto-plays English on correct pick.
///   Bug-5: After last question shows QuizReviewView before calling onComplete.
///   Bug-6: Skip (no score) and Too Easy (marks mastered) action buttons.
///   Bug-7: Hint button reveals correct answer inline.
struct QuizView: View {
    let session: [QuizItem]
    let context: ModelContext
    let stats: AppStats
    let onComplete: () -> Void
    /// Passed directly to avoid @Query deadlock during overlay teardown.
    let sessionTimeoutSeconds: Int?

    @State private var currentIndex = 0
    @State private var showFeedback = false
    @State private var feedbackCorrect = false
    @State private var isAdvancing = false   // blocks Skip/TooEasy/Hint while animating
    @State private var showHint = false
    @State private var showingReview = false

    private var currentItem: QuizItem { session[currentIndex] }

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.70, blue: 0.37)
                .ignoresSafeArea()

            if showingReview {
                QuizReviewView(words: session.map { $0.word }, onDone: onComplete)
                    .frame(width: 480, height: 420)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 24)
            } else {
                quizCard
            }
        }
        .onAppear { speakCurrentWord() }
        .onChange(of: currentIndex) { _, _ in
            showHint = false
            speakCurrentWord()
        }
    }

    // MARK: - Quiz card

    private var quizCard: some View {
        VStack(spacing: 14) {
            headerRow
            questionBlock
            if let timeout = sessionTimeoutSeconds {
                // Bug-2: NO .id(currentIndex) — one timer for the whole session.
                // Expiry hides overlay (onComplete), not just advances the question.
                QuizProgressBarView(totalSeconds: timeout, onExpire: onComplete)
            }
            answerArea
                .id(currentIndex)   // force new child view → resets picked/input state
            feedbackLabel
            actionRow
        }
        .padding(20)
        .frame(width: 440, height: 420)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 24)
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("\(currentIndex + 1) / \(session.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                // Defer so button action completes before close() tears down NSHostingView.
                DispatchQueue.main.async { onComplete() }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    /// Bug-4: Speaker icon always visible next to the displayed word.
    /// Bug-2-4: Example sentence shown for EN→VN questions.
    private var questionBlock: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(currentItem.direction == .enToVn
                     ? currentItem.word.english
                     : currentItem.word.vietnamese)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Button {
                    SpeechService.shared.speak(currentItem.word.english)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Text(currentItem.direction == .enToVn ? "→ Vietnamese?" : "→ English?")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Show example sentence for EN→VN so user understands context
            if currentItem.direction == .enToVn,
               let example = currentItem.word.exampleSentence, !example.isEmpty {
                Text("\"\(example)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }

            // Bug-7: Hint text revealed on demand
            if showHint {
                let answer = currentItem.direction == .enToVn
                    ? currentItem.word.vietnamese
                    : currentItem.word.english
                Text("Hint: \(answer)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
            }
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
            Text(feedbackCorrect ? "✓ Correct!" : "✗ Wrong — try again")
                .font(.headline)
                .foregroundStyle(feedbackCorrect ? .green : .red)
        } else {
            Text(" ").font(.headline)   // reserve space to avoid layout shift
        }
    }

    /// Bug-6: Skip / Too Easy   |   Bug-7: Hint
    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Hint") { showHint = true }
                .buttonStyle(.bordered)
                .disabled(showHint || isAdvancing)

            Spacer()

            Button("Skip") { skipCurrentWord() }
                .buttonStyle(.bordered)
                .disabled(isAdvancing)

            Button("Too Easy") { markTooEasy() }
                .buttonStyle(.bordered)
                .tint(.green)
                .disabled(isAdvancing)
        }
        .font(.caption)
    }

    // MARK: - Answer handling

    /// Called by child views for both correct and wrong answers.
    ///
    /// Bug-3:
    ///   - Wrong  → record, show brief "try again" feedback, DO NOT advance.
    ///   - Correct → record, auto-play speech (VN→EN), 3 s pause, then advance.
    private func advance(correct: Bool) {
        if correct {
            guard !isAdvancing else { return }
            isAdvancing = true
            SpacedRepetitionEngine.recordAnswer(
                word: currentItem.word, correct: true, stats: stats, context: context)

            // Bug-4: auto-play English when VN→EN question answered correctly
            if currentItem.direction == .vnToEn {
                SpeechService.shared.speak(currentItem.word.english)
            }

            feedbackCorrect = true
            showFeedback = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                showFeedback = false
                isAdvancing = false
                moveToNext()
            }
        } else {
            // Wrong: record but let the child view keep accepting picks/input
            SpacedRepetitionEngine.recordAnswer(
                word: currentItem.word, correct: false, stats: stats, context: context)
            feedbackCorrect = false
            showFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showFeedback = false
            }
        }
    }

    private func moveToNext() {
        showHint = false
        if currentIndex + 1 < session.count {
            currentIndex += 1
        } else {
            // Bug-5: show review card instead of dismissing immediately
            showingReview = true
        }
    }

    /// Bug-6: Skip — advance without recording any answer.
    private func skipCurrentWord() {
        guard !isAdvancing else { return }
        isAdvancing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isAdvancing = false
            moveToNext()
        }
    }

    /// Bug-6: Too Easy — instantly master the word, then skip.
    private func markTooEasy() {
        guard !isAdvancing else { return }
        currentItem.word.isMastered = true
        try? context.save()
        skipCurrentWord()
    }

    private func speakCurrentWord() {
        // Bug-4: auto-play English word for EN→VN questions on question appear
        if currentItem.direction == .enToVn {
            SpeechService.shared.speak(currentItem.word.english)
        }
    }
}
