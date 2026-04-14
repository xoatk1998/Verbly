import SwiftUI
import SwiftData

/// Sheet for editing an existing vocabulary word.
struct EditWordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let word: Word

    @State private var english: String
    @State private var vietnamese: String
    @State private var difficulty: String
    @State private var category: String
    @State private var exampleSentence: String
    @State private var isFetching = false
    @State private var fetchFailed = false

    init(word: Word) {
        self.word = word
        _english = State(initialValue: word.english)
        _vietnamese = State(initialValue: word.vietnamese)
        _difficulty = State(initialValue: word.difficulty)
        _category = State(initialValue: word.category)
        _exampleSentence = State(initialValue: word.exampleSentence ?? "")
    }

    private var isValid: Bool {
        !english.trimmingCharacters(in: .whitespaces).isEmpty &&
        !vietnamese.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            TextField("English", text: $english)
            TextField("Vietnamese", text: $vietnamese)

            Picker("Difficulty", selection: $difficulty) {
                ForEach(["B1", "B2", "C1", "C2"], id: \.self) { Text($0).tag($0) }
            }

            TextField("Category (optional)", text: $category)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Example sentence", text: $exampleSentence, axis: .vertical)
                        .lineLimit(2...3)
                    if fetchFailed {
                        Text("Not found")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if isFetching {
                    ProgressView().scaleEffect(0.7)
                } else if !english.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        Task { await fetchAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Fetch Vietnamese translation & example sentence")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 340)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(!isValid)
            }
        }
    }

    private func fetchAll() async {
        let w = english.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !isFetching else { return }

        isFetching = true
        fetchFailed = false

        async let translation = vietnamese.trimmingCharacters(in: .whitespaces).isEmpty
            ? TranslationService.translateToVietnamese(w)
            : nil
        async let example = ExampleSentenceService.fetch(for: w)

        let (vn, ex) = await (translation, example)

        if let vn { vietnamese = vn }
        if let ex { exampleSentence = ex }

        fetchFailed = vn == nil && ex == nil
        isFetching = false
    }

    private func save() {
        word.english = english.trimmingCharacters(in: .whitespaces)
        word.vietnamese = vietnamese.trimmingCharacters(in: .whitespaces)
        word.difficulty = difficulty
        word.category = category.trimmingCharacters(in: .whitespaces)
        let trimmed = exampleSentence.trimmingCharacters(in: .whitespaces)
        word.exampleSentence = trimmed.isEmpty ? nil : trimmed
        try? context.save()
        dismiss()
    }
}
