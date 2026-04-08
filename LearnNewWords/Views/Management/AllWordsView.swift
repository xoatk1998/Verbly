import SwiftUI
import SwiftData

/// "All Words" tab — full CRUD word list with search, difficulty filter, and CSV import.
struct AllWordsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.english) private var words: [Word]

    @State private var searchText = ""
    @State private var filterDifficulty = ""
    @State private var showAddSheet = false
    @State private var showImportPicker = false
    @State private var importResult: CSVImportService.ImportResult?
    @State private var showImportAlert = false

    private var filtered: [Word] {
        var result = words
        if !searchText.isEmpty {
            result = result.filter {
                $0.english.localizedCaseInsensitiveContains(searchText) ||
                $0.vietnamese.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !filterDifficulty.isEmpty {
            result = result.filter { $0.difficulty == filterDifficulty }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: search + add + import
            HStack(spacing: 6) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search…", text: $searchText).textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
                .help("Add word")

                Button { showImportPicker = true } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import CSV")
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Difficulty filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["", "B1", "B2", "C1", "C2"], id: \.self) { level in
                        Text(level.isEmpty ? "All" : level)
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(filterDifficulty == level
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.15))
                            .foregroundStyle(filterDifficulty == level ? .white : .primary)
                            .clipShape(Capsule())
                            .onTapGesture { filterDifficulty = level }
                    }
                }
                .padding(.horizontal, 10)
            }

            Divider().padding(.top, 6)

            List {
                ForEach(filtered, id: \.id) { word in
                    WordRowView(word: word)
                }
                .onDelete { indices in
                    indices.map { filtered[$0] }.forEach { context.delete($0) }
                    try? context.save()
                }
            }
            .listStyle(.plain)

            // Footer
            Text("\(filtered.count) / \(words.count) words")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        }
        .sheet(isPresented: $showAddSheet) {
            AddWordView()
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Complete", isPresented: $showImportAlert) {
            Button("OK") {}
        } message: {
            if let r = importResult {
                Text("Imported: \(r.imported)\nSkipped: \(r.skipped)\nErrors: \(r.errors.count)")
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importResult = CSVImportService.importFrom(url: url, context: context)
            showImportAlert = true
        case .failure(let error):
            importResult = CSVImportService.ImportResult(imported: 0, skipped: 0, errors: [error.localizedDescription])
            showImportAlert = true
        }
    }
}
