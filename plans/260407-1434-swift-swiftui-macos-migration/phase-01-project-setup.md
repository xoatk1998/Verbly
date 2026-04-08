# Phase 1: Project Setup

**Status**: Pending  
**Priority**: P0 (blocker for all phases)  
**Effort**: Small (1-2 days)

---

## Context Links
- [Plan Overview](plan.md)
- [Project Overview PDR](../../docs/project-overview-pdr.md)

---

## Overview

Create the Xcode project with proper structure, entitlements, and build settings for a macOS menu bar app.

---

## Requirements

- Xcode 15+ (Swift 5.9, SwiftData support)
- macOS 14 Sonoma minimum deployment target
- Menu bar app (LSUIElement = YES → no Dock icon)
- SwiftData container setup
- Basic app lifecycle established

---

## Implementation Steps

### 1. Create Xcode Project

```
File → New → Project → macOS → App
Product Name: LearnNewWords
Bundle ID: com.yourname.LearnNewWords
Interface: SwiftUI
Language: Swift
Storage: SwiftData
```

### 2. Configure Info.plist

Add these keys:
```xml
<!-- Hide from Dock — menu bar only app -->
<key>LSUIElement</key>
<true/>

<!-- App category -->
<key>LSApplicationCategoryType</key>
<string>public.app-category.education</string>
```

### 3. Configure Entitlements

`LearnNewWords.entitlements`:
```xml
<!-- For UserNotifications (quiz reminders) -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### 4. Entry Point Structure

`LearnNewWordsApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct LearnNewWordsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty — UI managed by AppDelegate via NSStatusItem
        Settings { EmptyView() }
    }
}
```

### 5. AppDelegate Skeleton

`AppDelegate.swift`:
```swift
import AppKit
import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupMenuBar()
        // QuizScheduler will be started in Phase 3
    }
}
```

### 6. Directory Structure

Create these empty files/folders in Xcode:
```
LearnNewWords/
├── App/LearnNewWordsApp.swift
├── App/AppDelegate.swift
├── Models/          (Phase 2)
├── Engine/          (Phase 3)
├── Views/Quiz/      (Phase 4)
├── Views/Management/(Phase 5)
├── Views/Components/(Phase 5)
├── Services/        (Phase 6)
└── Resources/sample.csv  ← copy from existing project
```

---

## Todo

- [ ] Create Xcode project with SwiftData template
- [ ] Set LSUIElement = YES in Info.plist
- [ ] Configure sandbox entitlements
- [ ] Create `LearnNewWordsApp.swift` entry point
- [ ] Create `AppDelegate.swift` skeleton
- [ ] Create directory structure
- [ ] Copy `sample.csv` into Resources group (Add to target)
- [ ] Verify build compiles with zero warnings

---

## Success Criteria

- App builds without errors
- Running the app shows NO Dock icon
- Menu bar shows a placeholder icon (e.g., `book` SF Symbol)
- App does not crash on launch

---

## Notes

- `LSUIElement = YES` is critical — this is what makes it a menu bar app
- SwiftData `ModelContainer` must be created once at app launch and shared
- Use `@NSApplicationDelegateAdaptor` to bridge SwiftUI App lifecycle with NSApplicationDelegate
