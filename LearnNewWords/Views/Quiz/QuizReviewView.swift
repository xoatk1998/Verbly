import SwiftUI

/// Post-quiz review card — EN ↔ VN pairs with speaker buttons.
struct QuizReviewView: View {
    let words: [Word]
    let onDone: () -> Void

    private let teal = Color(red: 0.05, green: 0.58, blue: 0.53)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(teal)
                        Text("Session Complete")
                            .font(.headline)
                    }
                    Text("\(words.count) word\(words.count == 1 ? "" : "s") reviewed")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { DispatchQueue.main.async { onDone() } }
                    .buttonStyle(.borderedProminent)
                    .tint(teal)
            }
            .padding(18)

            Divider()

            // Word list
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(words, id: \.id) { word in
                        HStack(spacing: 10) {
                            Button {
                                SpeechService.shared.speak(word.english)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(teal)
                            }
                            .buttonStyle(.plain)

                            Text(word.english)
                                .font(.subheadline).bold()
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(word.vietnamese)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(teal.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(14)
            }
        }
    }
}
