# Hohi Drive HUD — UI 2.1

Ứng dụng iPhone dẫn đường + BLE HUD ESP32.

## Giao diện
- SwiftUI hiện đại, nền lavender sáng, chỉ dùng hồng làm điểm nhấn.
- MapKit bản đồ thật.
- Nhập tối đa 5 chặng với nút **Thêm chặng**.
- Tab **Đơn hàng** lưu các chặng đã hoàn thành và cho nhập số lượng đơn.
- Không hiển thị QR trên iPhone.

## Logic OLED / QR
Khi hoàn thành một chặng, app gửi chuỗi VietQR xuống ESP32 bằng BLE trong gói `arrive`. OLED chịu trách nhiệm hiển thị QR. App chỉ hiện thông báo “Mã thanh toán đang được gửi tới OLED”. Khi bấm **Tiếp tục chặng tiếp theo**, app gửi dữ liệu navigation mới, firmware sẽ tắt QR và trở lại màn hình chỉ đường. Firmware hiện tại của dự án có cơ chế giữ QR 5 phút.

## Build GitHub Actions
Workflow dùng XcodeGen + xcodebuild trên macOS. Chỉ cần push toàn bộ thư mục này lên GitHub và chạy workflow `Build iOS`.
