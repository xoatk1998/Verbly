import SwiftUI
import SwiftData

/// "Words" tab — shows today's quiz words and learning progress.
/// Bug 2-3: "Today's Words" section lists the words scheduled for the next quiz.
///   Each word has a Replace button that postpones it 24 h so the next eligible
///   word takes its slot.
struct WordsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.addedAt, order: .reverse) private var words: [Word]
    @Query private var statsQuery: [AppStats]
    @Query private var settingsQuery: [AppSettings]

    @State private var searchText = ""

    private var stats: AppStats? { statsQuery.first }
    private var settings: AppSettings? { settingsQuery.first }

    // MARK: - Today's words (bug 2-3)

    /// Words that will appear in the next quiz session (top N eligible).
    private var todaysWords: [Word] {
        guard let s = settings, let st = stats else { return [] }
        let eligible = SpacedRepetitionEngine.eligibleWords(from: words, settings: s, stats: st)
        return Array(eligible.prefix(s.wordsPerPopup))
    }

    // MARK: - Browse list (all active words)

    private var displayWords: [Word] {
        let active = words.filter { !$0.isMastered }
        let filtered = searchText.isEmpty ? active : active.filter {
            $0.english.localizedCaseInsensitiveContains(searchText) ||
            $0.vietnamese.localizedCaseInsensitiveContains(searchText)
        }
        return Array(filtered.prefix(50))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Daily stats banner
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

                // Today's words section
                if !todaysWords.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's Quiz Words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)

                        ForEach(todaysWords, id: \.id) { word in
                            todayWordRow(word)
                        }
                    }

                    Divider().padding(.vertical, 8)
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search all words…", text: $searchText).textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

                if displayWords.isEmpty {
                    Text(searchText.isEmpty ? "No words due for review" : "No matches found")
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(displayWords, id: \.id) { word in
                            WordRowView(word: word)
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    /// A single row in the "Today's Quiz Words" section with a Replace button.
    private func todayWordRow(_ word: Word) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.english).font(.subheadline).bold()
                Text(word.vietnamese).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // Replace: postpone this word 24 h so the next eligible one takes its slot
            Button("Replace") { postponeWord(word) }
                .font(.caption)
                .buttonStyle(.bordered)
                .help("Postpone this word — next eligible word takes its place")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// Bug 2-3: Pushes `nextReviewAt` 24 h forward so word leaves today's eligible pool.
    private func postponeWord(_ word: Word) {
        word.nextReviewAt = Date().addingTimeInterval(24 * 60 * 60)
        try? context.save()
    }
}
