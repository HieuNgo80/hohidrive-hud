# HohiDrive HUD V10

This package is based directly on the supplied HohiDrive HUD project.

V10 stability changes:
- Guards MapKit route-step polyline access when a route step has zero points.
- Avoids starting location updates immediately before authorization.
- Preserves the existing UI, BLE, navigation, route/step data flow, and GitHub Actions structure.
- V9 backups of modified Swift files are retained beside the originals with `.V9.bak`.

Before building:
1. Open the Xcode project/workspace as supplied.
2. Build on a real iPhone.
3. If the app still exits immediately, collect the Xcode crash log; the next fix should be based on that log rather than changing unrelated UI/navigation behavior.


V10 patch pass status:
- Guarded 1 route-step polyline last-point access.
