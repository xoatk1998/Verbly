import SwiftUI
import SwiftData

/// Sheet for manually adding a single vocabulary word.
struct AddWordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var english = ""
    @State private var vietnamese = ""
    @State private var difficulty = "B1"
    @State private var category = ""

    private var isValid: Bool {
        !english.trimmingCharacters(in: .whitespaces).isEmpty &&
        !vietnamese.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            TextField("English", text: $english)
            TextField("Vietnamese", text: $vietnamese)
            Picker("Difficulty", selection: $difficulty) {
                ForEach(["B1", "B2", "C1", "C2"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            TextField("Category (optional)", text: $category)
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 270)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { addWord() }
                    .disabled(!isValid)
            }
        }
    }

    private func addWord() {
        let word = Word(
            english: english.trimmingCharacters(in: .whitespaces),
            vietnamese: vietnamese.trimmingCharacters(in: .whitespaces),
            difficulty: difficulty,
            category: category.trimmingCharacters(in: .whitespaces)
        )
        context.insert(word)
        try? context.save()
        dismiss()
    }
}
