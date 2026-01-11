# Shihou CBT Draft Trainer (macOS)

A macOS SwiftUI app for practicing司法試験CBT-style drafting with a fixed 3-pane layout.

## Requirements
- macOS 14+ (Sonoma)
- Xcode 15+ (Swift 5.9)

## How to Run
1. Open `LawExamEditer.xcodeproj` in Xcode.
2. Select the `LawExamEditer` scheme.
3. Run the app.

## Data Storage Location
All data is stored locally under:

```
~/Documents/ShihouDraft/
```

Structure:

```
~/Documents/ShihouDraft/
  Cases/<case-id>/
    draft.md
    notes.md
    meta.json
    attachments/
```

## Basic Workflow
1. **Create Case** in the top-right organizer pane.
2. Write in the left editor pane (auto-save runs after you stop typing).
3. Use **Cmd+S** to save immediately.
4. Enter a Goodnotes shared link in the URL field, then press **Load**.
5. The viewer loads in the bottom-right pane; sessions persist across restarts.

## Troubleshooting
- **URL invalid / unreachable**: The viewer shows an error with a retry button. Ensure the URL is valid and reachable.
- **Login issues**: Cookies are stored persistently. If the session expires, log in again in the embedded viewer.
- **Folder permissions**: The app writes to `~/Documents/ShihouDraft/`. Ensure your user account has access.

