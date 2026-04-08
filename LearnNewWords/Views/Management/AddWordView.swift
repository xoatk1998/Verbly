import SwiftUI
import SwiftData

/// Sheet for manually adding a single vocabulary word.
/// Bug 2-4: Auto-fetches an example sentence from the Free Dictionary API when
///   the user finishes typing the English word.
struct AddWordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var english = ""
    @State private var vietnamese = ""
    @State private var difficulty = "B1"
    @State private var category = ""
    @State private var exampleSentence = ""
    @State private var isFetchingExample = false

    private var isValid: Bool {
        !english.trimmingCharacters(in: .whitespaces).isEmpty &&
        !vietnamese.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            TextField("English", text: $english)
                .onSubmit { fetchExample() }

            TextField("Vietnamese", text: $vietnamese)

            Picker("Difficulty", selection: $difficulty) {
                ForEach(["B1", "B2", "C1", "C2"], id: \.self) {
                    Text($0).tag($0)
                }
            }

            TextField("Category (optional)", text: $category)

            // Example sentence row with fetch indicator
            HStack {
                TextField("Example sentence (auto-fetched)", text: $exampleSentence, axis: .vertical)
                    .lineLimit(2...3)
                if isFetchingExample {
                    ProgressView().scaleEffect(0.7)
                } else if !english.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        fetchExample()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Fetch example from dictionary")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 340)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { addWord() }
                    .disabled(!isValid)
            }
        }
        .onChange(of: english) { _, newValue in
            // Auto-fetch when user pauses typing (debounce via task)
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else { return }
            fetchExample()
        }
    }

    private func fetchExample() {
        let word = english.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty, !isFetchingExample else { return }
        isFetchingExample = true
        Task {
            if let sentence = await ExampleSentenceService.fetch(for: word) {
                exampleSentence = sentence
            }
            isFetchingExample = false
        }
    }

    private func addWord() {
        let word = Word(
            english: english.trimmingCharacters(in: .whitespaces),
            vietnamese: vietnamese.trimmingCharacters(in: .whitespaces),
            difficulty: difficulty,
            category: category.trimmingCharacters(in: .whitespaces),
            exampleSentence: exampleSentence.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : exampleSentence.trimmingCharacters(in: .whitespaces)
        )
        context.insert(word)
        try? context.save()
        dismiss()
    }
}
