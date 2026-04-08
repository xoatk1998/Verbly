import Foundation

/// Periodic quiz trigger. Replaces Chrome Alarms API.
///
/// Strategy mirrors content.js + background.js two-tier approach:
/// - Sub-minute intervals (< 60s): polls every second, fires when elapsed ≥ target
/// - Minute+ intervals (≥ 60s):    single timer set to exact interval
///
/// Shared singleton; wired in AppDelegate after ModelContainer is ready.
@MainActor
final class QuizScheduler {

    static let shared = QuizScheduler()

    /// Called when the scheduler decides it's time to show a quiz.
    var onTrigger: (() -> Void)?

    private var timer: Timer?
    private var lastFiredAt: Date = .distantPast

    private init() {}

    // MARK: - Control

    /// Starts (or restarts) the scheduler with a new interval.
    func start(intervalSeconds: Int) {
        stop()
        guard intervalSeconds > 0 else { return }

        let pollInterval: TimeInterval
        let targetInterval = TimeInterval(intervalSeconds)

        if intervalSeconds < 60 {
            // Poll every second so sub-minute triggers fire on time
            pollInterval = 1.0
        } else {
            // Poll at full interval; no need to check every second
            pollInterval = targetInterval
        }

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(self.lastFiredAt)
                if elapsed >= targetInterval {
                    self.lastFiredAt = Date()
                    self.onTrigger?()
                }
            }
        }
        // Allow timer to fire while tracking menus (important for menu bar apps)
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stops the scheduler without resetting lastFiredAt.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Updates the interval without losing lastFiredAt context.
    func updateInterval(_ seconds: Int) {
        start(intervalSeconds: seconds)
    }
}
