# V31 — ESP32 HUD BLE compatibility

Compared against the uploaded `ESP32_Navigation_HUD_V9` firmware.

Verified identifiers:
- Device: `ESP32_Sygic_HUD`
- Service: `DD3F0AD1-6239-4E1F-81F1-91F6C9F01D86`
- Write: `DD3F0AD3-6239-4E1F-81F1-91F6C9F01D86`

Changes:
- Scan all BLE advertisements, then accept only the exact HUD name or matching service UUID.
- Preserve reuse of already-connected peripherals.
- Use short no-response writes when safe.
- Use reliable with-response writes for larger packets.
- Fragment packets that exceed the negotiated write limit using the V9.1 firmware protocol.
- Send `distance` as integer metres, matching the firmware parser.
- Remove unused large fields (`route_points`, `actual_maneuver`, `next_road_sub`, `total_distance`) from live HUD packets.
- QR remains on the external OLED only.
