import SwiftUI
import SwiftData

/// "Stats" tab — accuracy, streak, mastery breakdown.
struct StatsView: View {
    @Query private var statsQuery: [AppStats]
    @Query private var words: [Word]

    private var stats: AppStats? { statsQuery.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Accuracy circle
                accuracySection

                Divider()

                // Stat cards grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Correct",   value: "\(stats?.correct ?? 0)",    color: .green)
                    StatCard(title: "Incorrect", value: "\(stats?.incorrect ?? 0)",  color: .red)
                    StatCard(title: "Streak",    value: "🔥 \(stats?.streak ?? 0)",  color: .orange)
                    StatCard(title: "Best",      value: "\(stats?.bestStreak ?? 0)", color: .purple)
                }

                Divider()

                // Word mastery bars
                masterySection
            }
            .padding()
        }
    }

    // MARK: - Subviews

    private var accuracySection: some View {
        VStack(spacing: 4) {
            Text("\(Int((stats?.accuracy ?? 0) * 100))%")
                .font(.system(size: 52, weight: .bold))
            Text("Overall Accuracy")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var masterySection: some View {
        let total = words.count
        let mastered = words.filter { $0.isMastered }.count
        let learning = words.filter { !$0.isMastered && ($0.correctCount > 0 || $0.incorrectCount > 0) }.count
        let newCount  = words.filter { $0.correctCount == 0 && $0.incorrectCount == 0 }.count

        return VStack(alignment: .leading, spacing: 10) {
            Text("Word Status").font(.headline)
            MasteryBarRow(label: "Mastered", count: mastered, total: total, color: .green)
            MasteryBarRow(label: "Learning", count: learning, total: total, color: .blue)
            MasteryBarRow(label: "New",      count: newCount, total: total, color: .gray)
        }
    }
}

// MARK: - Supporting views

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2).bold().foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct MasteryBarRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: total > 0
                               ? geo.size.width * CGFloat(count) / CGFloat(total)
                               : 0)
                }
            }
            .frame(height: 10)

            Text("\(count)")
                .font(.caption)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
