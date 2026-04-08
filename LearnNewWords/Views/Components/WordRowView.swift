import SwiftUI

/// Compact word list row showing English, Vietnamese, difficulty badge, and mastery status.
struct WordRowView: View {
    let word: Word

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.english)
                    .font(.body)
                    .bold()
                Text(word.vietnamese)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(word.difficulty)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(difficultyColor(word.difficulty).opacity(0.2))
                    .foregroundStyle(difficultyColor(word.difficulty))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(word.masteryLevel.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d {
        case "B1": return .green
        case "B2": return .blue
        case "C1": return .orange
        case "C2": return .red
        default:   return .gray
        }
    }
}
