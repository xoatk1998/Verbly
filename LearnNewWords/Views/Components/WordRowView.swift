import SwiftUI

/// Compact word row — English/Vietnamese pair with difficulty badge and mastery indicator.
struct WordRowView: View {
    let word: Word

    var body: some View {
        HStack(spacing: 10) {
            // Mastery dot
            Circle()
                .fill(masteryColor)
                .frame(width: 8, height: 8)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(word.english)
                    .font(.subheadline).bold()
                Text(word.vietnamese)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(word.difficulty)
                .font(.caption2).bold()
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(difficultyColor.opacity(0.15))
                .foregroundStyle(difficultyColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 5)
    }

    private var masteryColor: Color {
        switch word.masteryLevel {
        case .mastered: return .green
        case .learning: return Color(red: 0.05, green: 0.58, blue: 0.53)
        case .new:      return Color.secondary.opacity(0.5)
        }
    }

    private var difficultyColor: Color {
        switch word.difficulty {
        case "B1": return .green
        case "B2": return .blue
        case "C1": return .orange
        case "C2": return .red
        default:   return .gray
        }
    }
}
