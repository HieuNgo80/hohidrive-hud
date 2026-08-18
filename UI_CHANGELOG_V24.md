# HOHI DRIVE UI V24

## Kiến trúc giao diện mới
- Bottom Navigation Bar: **Home / Map / Order**.
- Giữ nguyên BLEManager + NavigationManager + logic gửi dữ liệu ESP32/HUD từ app cũ.
- UIKit ViewController cũ đã loại khỏi source để tránh xung đột với SwiftUI.

## Home
- Không còn map tĩnh.
- Form lộ trình được ghim cố định, không còn bottom sheet kéo/ẩn.
- Destination 1 mặc định trống, chỉ có placeholder.
- Chỉ khi chặng cuối đã có nội dung mới bật **Add Stop**.
- Tối đa 6 điểm đến.
- Danh sách chặng cuộn bên trong card nếu nhiều, nhưng card không bị ẩn/kéo.
- Xóa chặng theo UUID; callback tìm địa chỉ cũng tìm lại UUID trước khi ghi dữ liệu để tránh crash do index thay đổi.

## Map
- MKMapView thật, hỗ trợ pan / pinch zoom / rotate / pitch.
- Nút zoom + / -.
- Re-center về vị trí hiện tại.
- Heading/compass mode.
- Standard / Satellite / Hybrid.
- Navigation mode bám mockup: top maneuver card, route màu hồng, speed badge, Re-center, STOP, bottom stats.
- Trong menu Map Options có **Simulate Arrival** để test màn hình hoàn thành.

## Trip Completed
- Giao diện bám mockup sáng/trắng/tím.
- App **không render QR code**.
- Chỉ thông báo QR thanh toán đang hiển thị trên OLED ngoài.
- Continue to Next Stop hoặc Back to Home.

## Order
- Giữ lịch sử các chặng đã hoàn thành trong ngày và số lượng đơn cơ bản.
- Sẵn cấu trúc để phát triển chi tiết sau.
