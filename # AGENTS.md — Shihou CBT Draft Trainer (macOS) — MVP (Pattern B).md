# AGENTS.md — Shihou CBT Draft Trainer (macOS) — MVP (Pattern B)  
  
## 0. Objective  
Build a macOS app to practice drafting (司法試験CBT想定).  
UI is a fixed 3-pane layout:  
- Left (50% width): drafting editor  
- Right (50% width), split vertically:  
  - Top (33% height): case/file organizer + metadata  
  - Bottom (67% height): embedded Goodnotes shared-link viewer (WKWebView)  
  
The app must be usable immediately on a MacBook.  
  
## 1. Non-Negotiable Decisions (Confirmed)  
- Draft storage format: Markdown (.md) but treated as near-plain text (no template insertion)  
- Storage root: fixed directory under user home  
  - ~/Documents/ShihouDraft/  
- Goodnotes URL policy: accept ANY URL (typically https)  
  - Must provide robust error handling for invalid / unreachable URLs  
- Login: allowed inside WKWebView  
  - Persist cookies/sessions (use persistent WKWebsiteDataStore)  
  
## 2. Tech Stack (MVP)  
- Platform: macOS 14+ (Sonoma)  
- Language: Swift 5.9+  
- UI: SwiftUI; bridge to AppKit where needed (split view & WebView hosting)  
- Web rendering: WebKit (WKWebView)  
- Persistence: file system + UserDefaults  
- No network calls beyond WKWebView loading the provided URL  
  
## 3. Core Concepts & Data Model  
  
### 3.1 Case Workspace (Folder-Based)  
A "Case" is a folder on disk containing:  
- draft.md (main drafting text)  
- notes.md (optional notes)  
- meta.json (settings)  
- attachments/ (optional; PDFs etc.)  
  
#### meta.json fields (MVP)  
- id: UUID string  
- title: string  
- created_at: ISO8601 string  
- updated_at: ISO8601 string  
- goodnotes_url: string (may be empty)  
- active_editor: string (one of: "draft.md" | "notes.md"; default "draft.md")  
  
### 3.2 Storage Layout (Fixed)  
Root directory:  
- ~/Documents/ShihouDraft/  
  
Within it:  
- Cases/<case-id>/  
  - draft.md  
  - notes.md  
  - meta.json  
  - attachments/  
  
Do NOT use CoreData for MVP.  
  
## 4. UX Requirements (MVP)  
  
### 4.1 Layout  
- Default split proportions at first launch:  
  - Left = 50% width  
  - RightTop = 33% height of right pane  
  - RightBottom = 67% height of right pane  
- Allow user resizing via splitters  
- Persist split positions in UserDefaults and restore on launch  
  
### 4.2 Left Pane: Draft Editor (Near-Plain Text)  
- Edits the currently selected file (draft.md or notes.md) for the active Case  
- Treat as near-plain text editor:  
  - No template insertion feature  
  - No rich formatting toolbar required  
- Auto-save:  
  - Debounce writes (e.g., 1–2 seconds after last edit)  
  - Atomic write (write temp file then replace)  
- Manual save:  
  - Cmd+S triggers immediate write  
- Status display:  
  - Character count (required)  
  
#### Find UI (Required)  
- Cmd+F opens a small in-editor search bar (top overlay or top-of-pane)  
- Features (MVP):  
  - Text field for query  
  - Buttons: Next / Previous / Close  
  - Highlight current match and scroll to it  
  - If no matches, show a small message (“No matches”)  
  
### 4.3 Right Top Pane: Organizer  
- Case list with:  
  - Create Case (prompt title)  
  - Rename Case (update meta.json.title; folder name may remain stable)  
  - Delete Case (move to Trash; no silent permanent delete)  
- File list within Case:  
  - draft.md, notes.md, and attachments/  
  - Selecting draft.md / notes.md switches editor target  
  - Selecting a PDF in attachments:  
    - MVP: open via QuickLook or in a separate viewer window  
- Goodnotes URL controls:  
  - Text field bound to meta.json.goodnotes_url  
  - Buttons:  
    - Load (loads URL into web viewer)  
    - Clear (empties URL; web viewer shows placeholder)  
  
### 4.4 Right Bottom Pane: Goodnotes Viewer (WKWebView)  
- Embeds a WKWebView that loads meta.json.goodnotes_url  
- Buttons:  
  - Reload (re-load current URL)  
  - Open in Browser (open current URL with default browser)  
- Session persistence:  
  - Use persistent website data store so cookies/login survive app restarts  
- Error handling:  
  - Empty URL: show in-pane placeholder (“URL not set”)  
  - Invalid URL: show in-pane error message, do not crash  
  - Network error / load failure: show in-pane error + retry option  
  
## 5. Functional Requirements  
  
### 5.1 Case Management  
- Create Case:  
  - Create folder under ~/Documents/ShihouDraft/Cases/<uuid>/  
  - Write default draft.md and notes.md (can be empty)  
  - Write meta.json with title and timestamps  
- Delete Case:  
  - Move the case folder to Trash (preferred API)  
  - Update UI accordingly  
- Rename Case:  
  - Update meta.json.title and updated_at  
  - Keep id stable  
  
### 5.2 File I/O Safety  
- Use atomic writes for md and json  
- Never block UI thread on file IO (use background tasks/queues)  
- On corrupted meta.json:  
  - Show error banner  
  - Offer “Repair meta.json” (MVP: regenerate minimal meta keeping id if possible)  
  
### 5.3 Robust Error Handling (Hard Requirement)  
The app must never crash due to:  
- Missing files/folders  
- Permission errors  
- Bad JSON  
- Bad URL / unreachable host / offline  
- WKWebView load errors  
  
All such conditions must be handled with user-visible messages.  
  
## 6. Non-Functional Requirements  
- Startup time: < 2 seconds on typical MacBook  
- Offline: editor works; web viewer shows offline message  
- Privacy: all data stays local; no analytics  
- Security:  
  - No JS bridge exposing local file reads/writes to web content  
  - Do not inject arbitrary scripts into the loaded page  
  
## 7. Deliverables  
- Xcode project that builds and runs locally  
- README.md including:  
  - How to run (Xcode)  
  - Data storage location  
  - Basic workflow:  
    - Create Case -> write -> auto-save -> set Goodnotes URL -> load viewer  
  - Troubleshooting:  
    - URL invalid  
    - WebView login issues  
    - Data folder permissions  
- This AGENTS.md must be followed strictly  
  
## 8. Definition of Done (MVP)  
- App builds and runs  
- User can:  
  - Create Case -> type in editor -> auto-save -> quit -> reopen -> content persists  
  - Paste any URL -> Load -> view appears in embedded WKWebView  
  - Login inside WKWebView and remain logged in after app restart  
  - Reload / Open in Browser works  
  - Resize panes and the sizes persist across restarts  
- Under invalid URL/offline/missing file scenarios:  
  - App remains stable and shows actionable errors  
