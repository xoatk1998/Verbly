import SwiftUI
import SwiftData

/// "Stats" tab — accuracy ring, stat cards, mastery breakdown.
struct StatsView: View {
    @Query private var statsQuery: [AppStats]
    @Query private var words: [Word]

    private var stats: AppStats? { statsQuery.first }
    private let teal = Color(red: 0.05, green: 0.58, blue: 0.53)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                accuracyRing
                statGrid
                masterySection
            }
            .padding(16)
        }
    }

    // MARK: - Accuracy ring

    private var accuracyRing: some View {
        let pct = stats?.accuracy ?? 0
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(teal.opacity(0.12), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(teal, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: pct)
                VStack(spacing: 0) {
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(teal)
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: teal.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(icon: "checkmark.circle.fill", title: "Correct",
                     value: "\(stats?.correct ?? 0)",   color: .green)
            StatCard(icon: "xmark.circle.fill",    title: "Wrong",
                     value: "\(stats?.incorrect ?? 0)", color: .red)
            StatCard(icon: "flame.fill",            title: "Streak",
                     value: "\(stats?.streak ?? 0)",    color: .orange)
            StatCard(icon: "trophy.fill",           title: "Best",
                     value: "\(stats?.bestStreak ?? 0)", color: .purple)
        }
    }

    // MARK: - Mastery breakdown

    private var masterySection: some View {
        let total    = words.count
        let mastered = words.filter { $0.isMastered }.count
        let learning = words.filter { !$0.isMastered && ($0.correctCount > 0 || $0.incorrectCount > 0) }.count
        let newCount = words.filter { $0.correctCount == 0 && $0.incorrectCount == 0 }.count

        return VStack(alignment: .leading, spacing: 10) {
            Text("Word Status")
                .font(.subheadline).bold()
                .foregroundStyle(Color.primary)

            MasteryRow(label: "Mastered", icon: "star.fill",   count: mastered, total: total, color: .green)
            MasteryRow(label: "Learning", icon: "bolt.fill",   count: learning, total: total, color: teal)
            MasteryRow(label: "New",      icon: "sparkle",     count: newCount, total: total, color: .gray)
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: teal.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Supporting views

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2).bold()
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MasteryRow: View {
    let label: String
    let icon: String
    let count: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(label)
                .font(.caption)
                .frame(width: 58, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule().fill(color)
                        .frame(width: total > 0
                               ? geo.size.width * CGFloat(count) / CGFloat(total)
                               : 0)
                        .animation(.easeOut(duration: 0.5), value: count)
                }
            }
            .frame(height: 8)
            Text("\(count)")
                .font(.caption2).bold()
                .frame(width: 28, alignment: .trailing)
                .foregroundStyle(color)
        }
    }
}
