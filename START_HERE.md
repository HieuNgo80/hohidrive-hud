# Hohi Drive HUD — GitHub build

## Không cần Mac/Xcode
1. Tải ZIP này.
2. Giải nén.
3. Đưa **toàn bộ nội dung bên trong thư mục** lên repository GitHub.
4. Vào tab **Actions** → workflow **Build iOS** → **Run workflow**.
5. Sau khi build xong, vào run vừa build → **Artifacts** → tải `CatDriveHUD-ipa`.

Workflow tự cài XcodeGen, tạo `.xcodeproj` và build unsigned IPA trên máy macOS của GitHub Actions.

## Giao diện 2.1
- SwiftUI + MapKit thật.
- Nền lavender sáng, phong cách sạch/hiện đại.
- Hồng chỉ làm accent, không dùng neon hồng toàn màn hình.
- Tối đa 5 chặng, nút **Thêm chặng**.
- Tab **Đơn hàng** giữ lại, lưu các chặng hoàn thành và số lượng đơn.
- Không có QR image trên iPhone.
- Khi hoàn thành chặng, app gửi `qr` xuống ESP32; OLED hiển thị QR.
- Bấm **Tiếp tục chặng tiếp theo** sẽ gửi navigation mới để OLED quay lại màn hình chỉ đường.
