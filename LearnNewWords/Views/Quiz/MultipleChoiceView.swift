import SwiftUI

/// 2×2 grid of answer options.
/// Bug-1 fix: options stored in @State (initialised once in onAppear) so they
///   don't re-shuffle when QuizView re-renders and creates a new closure identity.
/// Bug-3 fix: wrong picks are tracked in a Set; other options stay enabled so
///   the user must find the correct answer rather than being auto-advanced.
struct MultipleChoiceView: View {
    let item: QuizItem
    let onAnswer: (Bool) -> Void

    @State private var options: [String] = []
    @State private var wrongPicks: Set<String> = []
    @State private var correctlyPicked = false

    private func correctAnswer() -> String {
        item.direction == .enToVn ? item.word.vietnamese : item.word.english
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button { pick(option) } label: {
                    Text(option)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .background(tileColor(for: option))
                        .cornerRadius(8)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                // Disable only: correctly-picked state (all done) OR this button was already wrong
                .disabled(correctlyPicked || wrongPicks.contains(option))
            }
        }
        .onAppear {
            // Shuffle once; onAppear doesn't re-fire on parent re-renders
            guard options.isEmpty else { return }
            options = ([correctAnswer()] + item.distractors).shuffled()
        }
    }

    private func pick(_ option: String) {
        guard !correctlyPicked, !wrongPicks.contains(option) else { return }
        if option == correctAnswer() {
            correctlyPicked = true
            onAnswer(true)
        } else {
            wrongPicks.insert(option)
            onAnswer(false)   // parent shows brief "try again" feedback, no auto-advance
        }
    }

    private func tileColor(for option: String) -> Color {
        // Only reveal green after user picks correctly (bug-3: don't highlight correct on wrong)
        if correctlyPicked && option == correctAnswer() { return .green.opacity(0.35) }
        if wrongPicks.contains(option) { return .red.opacity(0.35) }
        return Color.secondary.opacity(0.15)
    }
}
