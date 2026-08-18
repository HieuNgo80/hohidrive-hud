# HOHI DRIVE V27

Build fix after V26.

- Fixed Xcode error: `cannot find 'RecenterButton' in scope`.
- Root cause: `RecenterButton` was declared `private` inside `MapScreen.swift`, while `NavigationOverlay.swift` also referenced it.
- The shared control is now module-visible (`struct RecenterButton`) so both Map and Navigation UI can use it.
- Keeps the V26 Home keyboard/focus changes, `Add Location`, revised map controls, font update, and BLE connection-state changes.
- Version: 2.7 / Build 27.
