import SwiftUI

/// 2×2 grid of answer options. Highlights correct/wrong after selection.
struct MultipleChoiceView: View {
    let item: QuizItem
    let onAnswer: (Bool) -> Void

    @State private var selected: String?

    /// Correct answer + 3 distractors, shuffled once at view init.
    private let options: [String]

    init(item: QuizItem, onAnswer: @escaping (Bool) -> Void) {
        self.item = item
        self.onAnswer = onAnswer
        let correct = item.direction == .enToVn ? item.word.vietnamese : item.word.english
        self.options = ([correct] + item.distractors).shuffled()
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button {
                    guard selected == nil else { return }
                    pick(option)
                } label: {
                    Text(option)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .background(tileColor(for: option))
                        .cornerRadius(8)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(selected != nil)
            }
        }
    }

    private func correctAnswer() -> String {
        item.direction == .enToVn ? item.word.vietnamese : item.word.english
    }

    private func pick(_ option: String) {
        selected = option
        onAnswer(option == correctAnswer())
    }

    private func tileColor(for option: String) -> Color {
        guard let sel = selected else {
            return Color.secondary.opacity(0.15)
        }
        let correct = correctAnswer()
        if option == correct { return .green.opacity(0.35) }
        if option == sel     { return .red.opacity(0.35) }
        return Color.secondary.opacity(0.1)
    }
}
