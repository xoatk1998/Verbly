# Phase 1: Implementation

**Status**: Pending  
**Effort**: Tiny (~10 lines)  
**Files**: `AppDelegate.swift`, `QuizWindowController.swift`

---

## Change A — Right-click "Quit" on menu bar icon

**File**: `LearnNewWords/App/AppDelegate.swift`  
**Where**: Inside `setupMenuBar()`, after creating `statusItem`

The trick with `NSStatusItem` is that setting `.menu` directly disables left-click toggle.  
Instead, use a `NSStatusBarButton.sendAction(on:)` approach OR keep left-click for popover  
and right-click for menu via `willOpenMenu` delegate — the simplest approach is a  
`NSMenu` on the button only for right-click using `NSStatusItem.button.sendAction(on: [.rightMouseUp])`.

**Simplest correct pattern**:

```swift
// In setupMenuBar(), after statusItem is created:
let menu = NSMenu()
menu.addItem(withTitle: "Quit Learn New Words", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
// Attach menu only for right-click; left-click keeps toggling the popover
statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
// Override action to distinguish left vs right click:
button.action = #selector(handleStatusItemClick)
```

```swift
@objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent!
    if event.type == .rightMouseUp {
        statusItem?.menu = makeQuitMenu()
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // reset so left-click still works normally
    } else {
        togglePopover()
    }
}

private func makeQuitMenu() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(withTitle: "Quit Learn New Words",
                 action: #selector(NSApplication.terminate(_:)),
                 keyEquivalent: "")
    return menu
}
```

---

## Change B — Escape key dismisses quiz window

**File**: `LearnNewWords/Views/Quiz/QuizWindowController.swift`  
**Where**: Inside `makePanel()`, before returning

Two steps:
1. Call `panel.makeKey()` after `panel.makeKeyAndOrderFront(nil)` to ensure the panel receives key events
2. Add a local key monitor on the panel

```swift
// In show(), after panel.makeKeyAndOrderFront(nil):
panel.makeKey()

// In makePanel(), after setting collectionBehavior:
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
    if event.keyCode == 53 { // 53 = Escape
        self?.close()
        return nil  // consume event
    }
    return event
}
```

---

## Todo

- [ ] Read current `AppDelegate.swift` to find exact insertion point
- [ ] Add `handleStatusItemClick` + `makeQuitMenu` to `AppDelegate`
- [ ] Update `statusItem?.button?.action` and `sendAction(on:)` in `setupMenuBar()`
- [ ] Add `panel.makeKey()` call in `QuizWindowController.show()`
- [ ] Add Escape key local monitor in `QuizWindowController.makePanel()`
- [ ] Regenerate Xcode project (`xcodegen generate`)

---

## Success Criteria

- Right-clicking menu bar icon shows "Quit Learn New Words" menu item
- Left-clicking menu bar icon still opens the popover normally
- Pressing Escape while quiz is visible closes the quiz window
- Quiz Escape does NOT quit the entire app (just dismisses the window)
