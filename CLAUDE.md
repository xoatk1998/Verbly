# Chrome Extension Project: LearnNewWord

## Tech Stack

- Manifest V3
- React
- Shadow DOM for content script UI to avoid style bleeding

## Critical Rules

- **Permissions:** Never add a permission to `manifest.json` unless explicitly asked.
- **Content Scripts:** Always use `ISOLATED` world unless `MAIN` is required for page variables.
- **Background:** Use Service Workers (background.js). No persistent windows.

## Build & Test Commands

- **Lint:** `npx web-ext lint`
- **Build:** `npm run build`
- **Verify UI:** Use `claude --chrome` to open `chrome://extensions` and verify loading.

## Common Gotchas

- Always handle `chrome.runtime.lastError`.
- Use `action` instead of `browser_action` or `page_action`.
