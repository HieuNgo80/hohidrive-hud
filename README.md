# HOHI DRIVE HUD — V24

Ứng dụng iPhone SwiftUI + MapKit kết nối BLE với ESP32 HUD.

## UI V24
Bottom bar có 3 tab:
- **Home** — nhập tối đa 6 điểm đến theo thứ tự.
- **Map** — bản đồ thật tương tác và giao diện navigation.
- **Order** — lịch sử chặng đã hoàn thành; sẽ phát triển thêm sau.

## Logic cũ được giữ lại
- BLE service/write UUID tương thích firmware HUD hiện tại.
- MapKit / MKDirections.
- Route steps, maneuver, tên đường, ETA, tốc độ.
- Ngưỡng báo rẽ 100 m.
- Nhiều chặng.
- Khi hoàn thành từng chặng, app gửi `maneuver: arrive` + dữ liệu `qr` tới HUD.
- QR **không hiển thị trên iPhone**; OLED ngoài chịu trách nhiệm hiển thị.

## Build không cần Mac riêng
Repository đã có `.github/workflows/build.yml`.

1. Upload toàn bộ nội dung project này lên repository GitHub.
2. Vào **Actions → Build iOS → Run workflow**.
3. Tải artifact `CatDriveHUD-ipa`.
4. Cài `CatDriveHUD.ipa` bằng AltStore.

## Version
- App: 2.4
- Build: 24
- Deployment target: iOS 16+
