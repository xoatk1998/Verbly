import SwiftUI

/// Free-text input answer. Case-insensitive comparison. Enter key submits.
struct TypingAnswerView: View {
    let item: QuizItem
    let onAnswer: (Bool) -> Void

    @State private var input = ""
    @State private var submitted = false
    @FocusState private var focused: Bool

    private var correctAnswer: String {
        item.direction == .enToVn ? item.word.vietnamese : item.word.english
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Type your answer…", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .disabled(submitted)
                .onSubmit(submit)

            Button("Check", action: submit)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || submitted)
                .keyboardShortcut(.return)

            if submitted {
                Text("Answer: \(correctAnswer)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { focused = true }
    }

    private func submit() {
        guard !submitted else { return }
        submitted = true
        let isCorrect = input
            .trimmingCharacters(in: .whitespaces)
            .lowercased() == correctAnswer.lowercased()
        onAnswer(isCorrect)
    }
}
