# CatDriveHUD UI 2.3

## Giao diện map / route
- Route input chuyển thành bottom sheet bo tròn, có thể kéo lên/xuống để thu gọn.
- Không còn đổ toàn bộ danh sách chặng thành một panel dài ngay từ đầu.
- Chỉ có 1 chặng trống lúc mới mở app.
- Sau khi nhập chặng hiện tại, nút **Thêm chặng tiếp theo** cho phép thêm chặng 2, 3... tối đa 5 chặng.
- Ô địa chỉ chỉ dùng placeholder `Nhập điểm đến…`, không tự điền nội dung mẫu.
- Nút xóa chặng dùng UUID của từng chặng, tránh lỗi identity/index làm app văng.

## Giao diện đang di chuyển
- Map chuyển sang dark mode.
- Route line chuyển sang điểm nhấn hồng.
- Thêm nút **STOP** rõ ràng.
- Có thẻ hướng rẽ ở trên, tốc độ ở góc dưới trái, zoom +/-, định vị, hướng/compass và lớp bản đồ.
- Có thanh thông tin khoảng cách / giờ đến / thời gian còn lại ở dưới.
- Map vẫn hỗ trợ zoom, pan, rotate, pitch và định vị.

## Hoàn thành chặng
- Hiển thị màn hình hoàn thành theo phong cách mockup: dấu tick lớn, khoảng cách, thời gian và nút tiếp tục.
- Không hiển thị hình QR trong app.
- Chỉ thông báo thanh toán sẵn sàng trên thiết bị HUD; QR vẫn do OLED/HUD hiển thị.
- Có nút **Tiếp tục chặng tiếp theo** và **Về màn hình chính**.

## Đơn hàng
- Tab Đơn hàng cũ vẫn được giữ lại để phát triển tiếp.
