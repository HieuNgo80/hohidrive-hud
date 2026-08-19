# HOHI DRIVE V28

- Home: added decorative map hero to match the provided mock-up.
- Home: route card moved down and overlaps the hero area like the mock-up.
- Home: removed automatic TextField focus and automatic focus after Add Location.
- Home: destination ScrollView no longer dismisses keyboard interactively.
- Home: TextField binding now resolves each stop by UUID instead of capturing stale struct values.
- Home: Add Location remains visible and adds the next destination only after the previous one contains text.
- Bottom navigation rebuilt as a clean white 3-tab bar: Home / Map / Order.
- Map idle screen: removed HOHI DRIVE / HUD connection label overlay; speed remains.
- Arrival: strengthened automatic arrival detection using the current destination coordinate within 40 m.
- Arrival screen remains full-screen on the Map tab and QR is still shown only on the external OLED.
