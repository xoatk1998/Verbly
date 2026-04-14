import SwiftUI
import SwiftData

/// "Today" tab — shows today's pinned quiz words and recent word list.
/// Today's words are stable: Replace swaps only one slot; the list persists
/// across app restarts (same day) via AppStats.todayWordEnglish.
struct WordsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.addedAt, order: .reverse) private var words: [Word]
    @Query private var statsQuery: [AppStats]
    @Query private var settingsQuery: [AppSettings]

    /// Cached today's word list — stable across Replace taps and app restarts.
    @State private var todayWords: [Word] = []
    /// IDs of words postponed via Replace this session — excluded from future replacements.
    @State private var postponedIDs: Set<String> = []

    private var stats: AppStats? { statsQuery.first }
    private var settings: AppSettings? { settingsQuery.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                dailyBanner
                todaySection
            }
        }
        .onAppear { loadTodayWords() }
        .onChange(of: settings?.wordsPerPopup) { refreshTodayWords() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var dailyBanner: some View {
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
    }

    @ViewBuilder
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today's Quiz Words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { refreshTodayWords() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh — replace all words")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if todayWords.isEmpty {
                Text("No words available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                ForEach(todayWords, id: \.id) { word in
                    todayWordRow(word)
                }
            }
        }
        Divider().padding(.vertical, 8)
    }

    private func todayWordRow(_ word: Word) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.english).font(.subheadline).bold()
                Text(word.vietnamese).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Replace") { replaceWord(word) }
                .font(.caption)
                .buttonStyle(.bordered)
                .help("Swap this word — only this slot changes")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Today's words stability

    /// Load today's pinned list from AppStats (same day) or recompute fresh.
    private func loadTodayWords() {
        guard let s = settings, let st = stats else { return }
        let today = dayKey()

        if st.todayDateString == today,
           let pinned = st.todayWordEnglish, !pinned.isEmpty {
            let englishList = pinned.split(separator: "|").map(String.init)
            let wordMap = Dictionary(uniqueKeysWithValues: words.map { ($0.english, $0) })
            let restored = englishList.compactMap { wordMap[$0] }
            if !restored.isEmpty {
                todayWords = restored
                return
            }
        }

        // Fresh: compute eligible words for today, then pad to wordsPerPopup
        // if the quota-limited pool is smaller than the target count.
        let eligible = SpacedRepetitionEngine.eligibleWords(from: Array(words), settings: s, stats: st)
        var list = Array(eligible.prefix(s.wordsPerPopup))

        if list.count < s.wordsPerPopup {
            let existingIDs = Set(list.map { $0.id })
            let extras = words.filter { !existingIDs.contains($0.id) && !$0.isMastered }.shuffled()
            list += Array(extras.prefix(s.wordsPerPopup - list.count))
        }

        todayWords = list
        savePinned(st)
    }

    /// Replace one slot: postpone the tapped word, swap in the next available word.
    private func replaceWord(_ word: Word) {
        guard let st = stats else { return }

        // Postpone the replaced word (makes isDueForReview return false immediately
        // since Word is a reference type — no need to wait for @Query refresh).
        postponedIDs.insert(word.id)
        word.nextReviewAt = Date().addingTimeInterval(24 * 60 * 60)
        try? context.save()

        // Exclude current list + all previously postponed words so replacements never loop.
        let excluded = Set(todayWords.map { $0.id }).union(postponedIDs)
        let next = words.first { !excluded.contains($0.id) && !$0.isMastered && $0.isDueForReview }
            ?? words.first { !excluded.contains($0.id) && !$0.isMastered }

        if let idx = todayWords.firstIndex(where: { $0.id == word.id }) {
            if let next {
                todayWords[idx] = next
            } else {
                todayWords.remove(at: idx)
            }
        }

        savePinned(st)
    }

    /// Refresh button: discard cache and recompute all slots from scratch.
    private func refreshTodayWords() {
        guard let s = settings, let st = stats else { return }
        let eligible = SpacedRepetitionEngine.eligibleWords(from: Array(words), settings: s, stats: st)
        var list = Array(eligible.prefix(s.wordsPerPopup))
        if list.count < s.wordsPerPopup {
            let existingIDs = Set(list.map { $0.id })
            let extras = words.filter { !existingIDs.contains($0.id) && !$0.isMastered }.shuffled()
            list += Array(extras.prefix(s.wordsPerPopup - list.count))
        }
        todayWords = list
        savePinned(st)
    }

    private func savePinned(_ st: AppStats) {
        st.todayWordEnglish = todayWords.map { $0.english }.joined(separator: "|")
        st.todayDateString = dayKey()
        try? context.save()
    }

    private func dayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}
