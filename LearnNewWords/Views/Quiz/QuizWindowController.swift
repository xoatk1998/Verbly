import AppKit
import SwiftUI
import SwiftData

/// Manages the full-screen quiz overlay.
///
/// Safety layers (in order of escalation):
///   1. X button / Escape / Cmd+Q in the UI
///   2. Local + global NSEvent key monitors
///   3. Hard watchdog: background thread calls exit(0) if overlay is stuck > `watchdogSeconds`
///   4. Auto-close on system sleep (laptop lid close)
@MainActor
final class QuizWindowController {

    private var overlayWindows: [NSWindow] = []

    // Watchdog — runs on a background thread so it survives a frozen main thread
    private var watchdogWorkItem: DispatchWorkItem?
    /// Seconds before the watchdog force-terminates the process. Default: quiz timeout + 60s buffer.
    private let watchdogSeconds: Int = 90

    private var sleepObserver: Any?

    // MARK: - Public API

    func show(session: [QuizItem], context: ModelContext, stats: AppStats, sessionTimeoutSeconds: Int?) {
        guard !session.isEmpty else { return }
        close()

        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]

        for screen in NSScreen.screens {
            let window = makeOverlayWindow(for: screen)

            if screen == activeScreen {
                let quizView = QuizView(
                    session: session,
                    context: context,
                    stats: stats,
                    onComplete: { [weak self] in self?.close() },
                    sessionTimeoutSeconds: sessionTimeoutSeconds
                )
                window.contentView = NSHostingView(rootView: quizView)
                window.makeKeyAndOrderFront(nil)
                // Give keyboard focus to the content view so SwiftUI's @FocusState
                // (used by TypingAnswerView's TextField) activates correctly.
                window.makeFirstResponder(window.contentView)
            } else {
                window.contentView = NSHostingView(rootView: Color.green.ignoresSafeArea())
                window.ignoresMouseEvents = true
                window.orderFront(nil)
            }

            overlayWindows.append(window)
        }

        setupKeyMonitors()
        startWatchdog()
        observeSleep()
    }

    /// Tears down all overlay windows and cancels all safety mechanisms.
    func close() {
        cancelWatchdog()
        removeSleepObserver()
        removeKeyMonitors()

        let windows = overlayWindows
        overlayWindows.removeAll()

        // Phase 1: Immediately hide every overlay (instant visual feedback,
        // no SwiftUI teardown — orderOut just removes the window from screen).
        windows.forEach { $0.orderOut(nil) }

        // Phase 2: Defer the actual SwiftUI view-hierarchy destruction.
        // NSWindow.close() (or setting contentView = nil) triggers a synchronous
        // teardown on the main thread. Internal SwiftData @Query observation
        // cleanup schedules @MainActor-isolated work that can never execute
        // because the main thread is already blocked inside the teardown
        // → deadlock → spinning cursor.
        // By deferring to asyncAfter, the current call stack unwinds first,
        // giving the main-actor executor a chance to drain queued work between
        // each run-loop iteration before the windows are finally released.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for window in windows {
                window.contentView = nil
                window.close()
            }
        }
    }

    // MARK: - Watchdog (background thread — survives frozen main thread)

    private func startWatchdog() {
        let item = DispatchWorkItem {
            // Fires on a background thread — works even if main thread is frozen.
            // The overlay has been visible longer than watchdogSeconds; force-quit.
            exit(0)
        }
        watchdogWorkItem = item
        DispatchQueue.global(qos: .background).asyncAfter(
            deadline: .now() + .seconds(watchdogSeconds),
            execute: item
        )
    }

    private func cancelWatchdog() {
        watchdogWorkItem?.cancel()
        watchdogWorkItem = nil
    }

    // MARK: - Sleep observer (auto-close when laptop lid closes)

    private func observeSleep() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.close() }
        }
    }

    private func removeSleepObserver() {
        if let obs = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            sleepObserver = nil
        }
    }

    // MARK: - Key monitors

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    private func setupKeyMonitors() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isDismissKey(event) == true { self?.close(); return nil }
            return event
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isDismissKey(event) == true {
                DispatchQueue.main.async { self?.close() }
            }
        }
    }

    private func removeKeyMonitors() {
        if let m = localKeyMonitor  { NSEvent.removeMonitor(m); localKeyMonitor  = nil }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
    }

    /// Escape, Cmd+Q, or Cmd+W all dismiss the overlay.
    private func isDismissKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { return true } // Escape
        if event.modifierFlags.contains(.command) {
            if event.keyCode == 12 { return true } // Cmd+Q
            if event.keyCode == 13 { return true } // Cmd+W
        }
        return false
    }

    // MARK: - Window factory

    /// Borderless NSWindow subclass that allows becoming the key window.
    /// Plain borderless windows have canBecomeKey = false by default, so
    /// makeKey() is silently ignored — keyboard events never reach SwiftUI
    /// views (TextField, etc.). Overriding fixes typing in TypingAnswerView.
    private final class KeyableOverlayWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    private func makeOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = KeyableOverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        // Level 500: above all normal apps and the Dock/menu bar,
        // but below macOS system overlays (login screen, Force Quit dialog at ~2147483000).
        // This means Cmd+Option+Escape (Force Quit) always works as a last resort.
        window.level = NSWindow.Level(rawValue: 500)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false
        return window
    }
}
