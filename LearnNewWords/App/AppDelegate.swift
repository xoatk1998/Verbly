import AppKit
import SwiftUI
import SwiftData

/// Central coordinator: menu bar status item, ModelContainer, quiz scheduling, and popover UI.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var modelContainer: ModelContainer?
    private let quizWindowController = QuizWindowController()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupMenuBar()
        setupQuizScheduler()
    }

    func applicationWillTerminate(_ notification: Notification) {
        try? modelContainer?.mainContext.save()
    }

    // MARK: - ModelContainer

    private func setupModelContainer() {
        let schema = Schema([Word.self, AppSettings.self, AppStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            seedDefaultsIfNeeded()
        } catch {
            fatalError("[LearnNewWords] ModelContainer failed: \(error)")
        }
    }

    /// Creates default AppSettings/AppStats singletons and seeds words on first launch.
    private func seedDefaultsIfNeeded() {
        guard let context = modelContainer?.mainContext else { return }

        let settingsCount = (try? context.fetchCount(FetchDescriptor<AppSettings>())) ?? 0
        if settingsCount == 0 { context.insert(AppSettings()) }

        let statsCount = (try? context.fetchCount(FetchDescriptor<AppStats>())) ?? 0
        if statsCount == 0 { context.insert(AppStats()) }

        // Load bundled sample.csv on first launch (no words yet)
        let wordCount = (try? context.fetchCount(FetchDescriptor<Word>())) ?? 0
        if wordCount == 0 { CSVImportService.loadSeedWords(context: context) }

        try? context.save()
    }

    // MARK: - Quiz Scheduling

    private func setupQuizScheduler() {
        guard let context = modelContainer?.mainContext,
              let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first,
              settings.isEnabled else { return }

        QuizScheduler.shared.onTrigger = { [weak self] in
            self?.triggerQuiz()
        }
        QuizScheduler.shared.start(intervalSeconds: settings.effectiveIntervalSeconds)
    }

    /// Builds a quiz session and presents the floating quiz panel.
    /// - Parameter force: When true (Practice Now button), bypasses daily quota and review
    ///   schedule so the user always gets a session. Automatic scheduler passes false.
    func triggerQuiz(force: Bool = false) {
        guard let context = modelContainer?.mainContext,
              let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first,
              let stats = try? context.fetch(FetchDescriptor<AppStats>()).first else { return }

        // Automatic triggers respect isEnabled; manual "Practice Now" always runs
        if !force && !settings.isEnabled { return }

        let allWords = (try? context.fetch(FetchDescriptor<Word>())) ?? []

        // Build eligible pool; for forced sessions fall back to any non-mastered word
        var eligible = SpacedRepetitionEngine.eligibleWords(from: allWords, settings: settings, stats: stats)
        if eligible.isEmpty && force {
            eligible = allWords.filter { !$0.isMastered }.shuffled()
        }

        let session = QuizSessionBuilder.buildSession(from: eligible, allWords: allWords, settings: settings)
        guard !session.isEmpty else { return }

        // Track new words shown today
        let newShown = session.filter { $0.word.correctCount == 0 && $0.word.incorrectCount == 0 }
        stats.dailyNewWordsToday += newShown.count
        try? context.save()

        quizWindowController.show(session: session, context: context, stats: stats, sessionTimeoutSeconds: settings.sessionTimeoutSeconds)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "graduationcap.fill",
                accessibilityDescription: "Learn New Words"
            )
            // Listen for both left and right mouse clicks
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleStatusItemClick)
            button.target = self
        }

        guard let container = modelContainer else { return }

        let popoverView = MenuBarPopoverView(onTriggerQuiz: { [weak self] in self?.triggerQuiz(force: true) })
            .modelContainer(container)

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverView)
        self.popover = popover
    }

    /// Routes left-click → popover, right-click → quit menu.
    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Show quit menu on right-click; reset afterwards so left-click stays normal
            statusItem?.menu = makeStatusMenu()
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePopover()
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Learn New Words",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        return menu
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
