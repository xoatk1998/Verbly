import SwiftUI
import SwiftData

/// "Words" tab — shows due/learning words and today's progress.
struct WordsListView: View {
    @Query(sort: \Word.addedAt, order: .reverse) private var words: [Word]
    @Query private var statsQuery: [AppStats]

    @State private var searchText = ""

    private var stats: AppStats? { statsQuery.first }

    private var displayWords: [Word] {
        let active = words.filter { !$0.isMastered }
        let filtered = searchText.isEmpty ? active : active.filter {
            $0.english.localizedCaseInsensitiveContains(searchText) ||
            $0.vietnamese.localizedCaseInsensitiveContains(searchText)
        }
        return Array(filtered.prefix(30))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Daily progress banner
            if let s = stats {
                HStack {
                    Text("Today: \(s.dailyNewWordsToday) new words")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if s.streak > 0 {
                        Text("🔥 \(s.streak) streak")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.05))

                Divider()
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search…", text: $searchText).textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(10)

            if displayWords.isEmpty {
                Spacer()
                Text(searchText.isEmpty ? "No words due for review" : "No matches found")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(displayWords, id: \.id) { word in
                    WordRowView(word: word)
                }
                .listStyle(.plain)
            }
        }
    }
}
