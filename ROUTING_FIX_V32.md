# V32 routing/payment changes

- Payment QR data entry moved to the Order tab and persisted in UserDefaults.
- Completion sends the saved QR payload to the external OLED; the iPhone never renders the QR image.
- Automatic rerouting when the vehicle remains off the current route for consecutive GPS samples.
- Turn distance now follows each MKRoute.Step polyline instead of straight-line distance to the step endpoint.
- GPS quality filtering and automotive navigation settings added.
- Roundabout instructions are detected, exit numbers are extracted when MapKit provides them, and the HUD receives `roundabout_exit`.
