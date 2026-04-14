import SwiftUI
import SwiftData

/// Full-screen quiz overlay with redesigned teal card UI.
struct QuizView: View {
    let session: [QuizItem]
    let context: ModelContext
    let stats: AppStats
    let onComplete: () -> Void
    let sessionTimeoutSeconds: Int?
    /// Custom background color from settings. nil = default teal gradient.
    var overlayColor: Color? = nil

    @State private var currentIndex = 0
    @State private var showFeedback = false
    @State private var feedbackCorrect = false
    @State private var isAdvancing = false
    @State private var showHint = false
    @State private var showingReview = false

    private let teal = Color(red: 0.05, green: 0.58, blue: 0.53)
    private var currentItem: QuizItem { session[currentIndex] }

    var body: some View {
        ZStack {
            // Background: custom color if set, else default teal gradient
            if let color = overlayColor {
                color.ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.58, blue: 0.53),
                        Color(red: 0.02, green: 0.42, blue: 0.39)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 280).offset(x: 160, y: -140)
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 200).offset(x: -140, y: 160)

            if showingReview {
                QuizReviewView(words: session.map { $0.word }, onDone: onComplete)
                    .frame(width: 500, height: 440)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 32, x: 0, y: 8)
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
        VStack(spacing: 0) {
            cardHeader
            Divider().opacity(0.15)
            cardBody
        }
        .frame(width: 460)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.25), radius: 32, x: 0, y: 8)
    }

    private var cardHeader: some View {
        HStack {
            // Progress pills
            HStack(spacing: 4) {
                ForEach(session.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentIndex ? teal : Color.secondary.opacity(0.2))
                        .frame(width: i == currentIndex ? 20 : 8, height: 6)
                        .animation(.spring(response: 0.3), value: currentIndex)
                }
            }
            Spacer()
            Text("\(currentIndex + 1) / \(session.count)")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                DispatchQueue.main.async { onComplete() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var cardBody: some View {
        VStack(spacing: 14) {
            if let timeout = sessionTimeoutSeconds {
                QuizProgressBarView(totalSeconds: timeout, onExpire: onComplete)
                    .padding(.horizontal, 20)
            }

            questionBlock
                .padding(.horizontal, 20)

            feedbackBanner

            answerArea
                .padding(.horizontal, 20)
                .id(currentIndex)

            actionRow
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .padding(.top, 10)
    }

    // MARK: - Question

    private var questionBlock: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(currentItem.direction == .enToVn
                     ? currentItem.word.english
                     : currentItem.word.vietnamese)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)

                Button {
                    SpeechService.shared.speak(currentItem.word.english)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(teal)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            Label(
                currentItem.direction == .enToVn ? "Translate to Vietnamese" : "Translate to English",
                systemImage: currentItem.direction == .enToVn ? "arrow.right" : "arrow.left"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if currentItem.direction == .enToVn,
               let ex = currentItem.word.exampleSentence, !ex.isEmpty {
                Text("\"\(ex)\"")
                    .font(.caption).italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if showHint {
                let answer = currentItem.direction == .enToVn
                    ? currentItem.word.vietnamese : currentItem.word.english
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill").font(.caption2)
                    Text(answer).font(.caption).bold()
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.orange.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(teal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Feedback

    @ViewBuilder
    private var feedbackBanner: some View {
        if showFeedback {
            HStack(spacing: 6) {
                Image(systemName: feedbackCorrect ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                Text(feedbackCorrect ? "Correct!" : "Try again…")
                    .font(.subheadline).bold()
            }
            .foregroundStyle(feedbackCorrect ? .green : .orange)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background((feedbackCorrect ? Color.green : Color.orange).opacity(0.12))
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
        } else {
            Color.clear.frame(height: 30)
        }
    }

    // MARK: - Answer area

    @ViewBuilder
    private var answerArea: some View {
        if currentItem.answerMode == .choice {
            MultipleChoiceView(item: currentItem, onAnswer: advance)
        } else {
            TypingAnswerView(item: currentItem, onAnswer: advance)
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            actionButton("lightbulb", "Hint", .orange) { showHint = true }
                .disabled(showHint || isAdvancing)
            Spacer()
            actionButton("forward.fill", "Skip", .secondary) { skipCurrentWord() }
                .disabled(isAdvancing)
            actionButton("checkmark.seal.fill", "Too Easy", teal) { markTooEasy() }
                .disabled(isAdvancing)
        }
    }

    private func actionButton(_ icon: String, _ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption).bold()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func advance(correct: Bool) {
        if correct {
            guard !isAdvancing else { return }
            isAdvancing = true
            SpacedRepetitionEngine.recordAnswer(word: currentItem.word, correct: true, stats: stats, context: context)
            if currentItem.direction == .vnToEn {
                SpeechService.shared.speak(currentItem.word.english)
            }
            withAnimation(.spring(response: 0.3)) {
                feedbackCorrect = true; showFeedback = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { showFeedback = false }
                isAdvancing = false
                moveToNext()
            }
        } else {
            SpacedRepetitionEngine.recordAnswer(word: currentItem.word, correct: false, stats: stats, context: context)
            withAnimation(.spring(response: 0.3)) {
                feedbackCorrect = false; showFeedback = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { showFeedback = false }
            }
        }
    }

    private func moveToNext() {
        showHint = false
        if currentIndex + 1 < session.count { currentIndex += 1 }
        else { withAnimation { showingReview = true } }
    }

    private func skipCurrentWord() {
        guard !isAdvancing else { return }
        isAdvancing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isAdvancing = false; moveToNext()
        }
    }

    private func markTooEasy() {
        guard !isAdvancing else { return }
        currentItem.word.isMastered = true
        try? context.save()
        skipCurrentWord()
    }

    private func speakCurrentWord() {
        if currentItem.direction == .enToVn {
            SpeechService.shared.speak(currentItem.word.english)
        }
    }
}
