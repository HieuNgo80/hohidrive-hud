# START HERE — HOHI DRIVE V24

Bạn **không cần Mac/Xcode trên máy cá nhân** để build bản này.

## Upload lên GitHub
1. Giải nén `hohidrive-hud-V24-GitHub.zip`.
2. Mở thư mục `hohidrive-hud-V24` bên trong.
3. Upload **toàn bộ nội dung** lên repo `HieuNgo80/hohidrive-hud`, thay cho source cũ.
4. Đảm bảo `.github/workflows/build.yml` vẫn có trên GitHub.

## Build IPA
1. GitHub → tab **Actions**.
2. Chọn **Build iOS**.
3. **Run workflow**.
4. Khi xong tải artifact `CatDriveHUD-ipa`.
5. Giải nén artifact để lấy `CatDriveHUD.ipa`, cài bằng AltStore.

## Test UI
- **Home**: nhập Destination 1; khi đã có nội dung nút Add Stop mới hoạt động.
- **Map**: pan, pinch zoom, rotate; Re-center; compass/heading; +/-; đổi lớp bản đồ.
- Khi đang navigation: menu dấu `...` → **Simulate Arrival** để test giao diện Trip Completed.
- **Order**: lịch sử các chặng đã hoàn thành.

## QR
Ứng dụng không hiển thị QR. Khi hoàn thành chặng, dữ liệu thanh toán được gửi qua BLE cho HUD/OLED theo logic cũ.
