import SwiftUI

/// Animated countdown bar. Turns red in the final 30% of time.
/// Calls `onExpire` when the countdown reaches zero.
///
/// Uses a RunLoop Timer (not Task.sleep) so teardown via onDisappear is
/// purely synchronous — no actor hopping required when the quiz window closes.
/// This eliminates the spinning-cursor deadlock: the old @MainActor async
/// approach meant SwiftUI had to wait for the task to re-acquire the main
/// actor before it could confirm cancellation, but the main actor was already
/// blocked executing close(), causing a deadlock and spinning cursor.
struct QuizProgressBarView: View {
    let totalSeconds: Int
    let onExpire: () -> Void

    @State private var remaining: Double = 1.0
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.2))
                RoundedRectangle(cornerRadius: 3)
                    .fill(remaining > 0.3 ? Color.accentColor : Color.red)
                    .frame(width: geo.size.width * remaining)
                    .animation(.linear(duration: 1), value: remaining)
            }
        }
        .frame(height: 6)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func startTimer() {
        remaining = 1.0
        let total = totalSeconds
        let start = Date()
        // Timer fires on the main RunLoop (scheduled from onAppear on main thread).
        // MainActor.assumeIsolated tells Swift the callback is safely on the main
        // thread, allowing @State mutations and @MainActor calls without async hops.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                let elapsed = Int(Date().timeIntervalSince(start))
                remaining = max(0, 1.0 - Double(elapsed) / Double(total))
                if elapsed >= total {
                    stopTimer()
                    onExpire()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
