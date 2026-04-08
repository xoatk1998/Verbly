import SwiftUI

/// Post-quiz review card shown after all session questions are answered.
/// Displays each word as EN → VN with a speaker button (bug-5).
struct QuizReviewView: View {
    let words: [Word]
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Complete")
                        .font(.headline)
                    Text("\(words.count) word\(words.count == 1 ? "" : "s") reviewed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    DispatchQueue.main.async { onDone() }
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // Word list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(words, id: \.id) { word in
                        HStack {
                            Text(word.english)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(word.vietnamese)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                SpeechService.shared.speak(word.english)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(20)
    }
}
