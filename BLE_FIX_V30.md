# BLE fix V30

The previous app build accidentally used BLE UUIDs that do not match the ESP32 HUD firmware.

Correct firmware identifiers restored in V30:
- Service UUID: `DD3F0AD1-6239-4E1F-81F1-91F6C9F01D86`
- Write characteristic: `DD3F0AD3-6239-4E1F-81F1-91F6C9F01D86`
- ESP32 advertised name: `ESP32_Sygic_HUD`

V30 also:
- reuses an existing iOS BLE connection when possible;
- reports Connected only after the WRITE characteristic is actually discovered;
- retries automatically after a disconnect/failure;
- chooses `.withoutResponse` when the firmware characteristic supports it.
