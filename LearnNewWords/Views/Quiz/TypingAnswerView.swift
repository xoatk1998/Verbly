import SwiftUI

/// Free-text input answer. Case-insensitive comparison. Enter key submits.
/// Bug-3 fix: wrong submit clears the field and lets the user retry rather
///   than locking the input and auto-advancing.
struct TypingAnswerView: View {
    let item: QuizItem
    let onAnswer: (Bool) -> Void

    @State private var input = ""
    @State private var submitted = false   // true only after a CORRECT answer
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
                .onSubmit { submit() }

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
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !submitted else { return }

        let isCorrect = trimmed.lowercased() == correctAnswer.lowercased()
        if isCorrect {
            submitted = true        // lock field, show correct answer below
            onAnswer(true)
        } else {
            onAnswer(false)         // parent records wrong + shows brief feedback
            input = ""              // clear so user can retype
            focused = true
        }
    }
}
