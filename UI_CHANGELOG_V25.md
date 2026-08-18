# UI / Build Changelog V25

## Build fix
- Replaced the Release-only type-check-heavy `flatMap().contains()` expression in `MapViewRepresentable.swift` with a small recursive gesture helper.
- `project.yml` now uses an explicit allow-list of the V25 source files/directories. Old files such as `ViewController.swift`, `ViewController.swift.V9.bak`, and `ViewController.swift.UI.bak` can remain in the GitHub repository without being compiled or copied into the app.
- GitHub Actions now removes any old generated `.xcodeproj`, `build`, and `Payload` directories before running XcodeGen.
- Build number bumped to 25 / app version 2.5.

## UI / app logic
- Keeps the V24 Home / Map / Order UI and existing BLE/navigation integration.
- QR remains OLED-only; the iPhone UI never renders the QR image.
