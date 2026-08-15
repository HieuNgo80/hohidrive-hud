# Hohi Drive HUD — App iOS (Apple MapKit) + ESP32

App điều hướng **Apple MapKit** trên iPhone, gửi dữ liệu qua **BLE** tới ESP32-C3 HUD.
Không cần Mac, **không cần Google Cloud / API key / thẻ thanh toán** — hoàn toàn miễn phí:
build bằng GitHub Actions (macOS đám mây) + cài bằng AltStore (Apple ID thường).

> **Bản V8+:** dùng Apple MapKit (bản đồ Apple, free 100%).
> **Bản 1.9 / build 10:** tách tên đường khỏi câu chỉ dẫn, hỗ trợ U-turn và chỉ đổi mũi tên rẽ khi còn ≤100 m.
> Không cần bật API, không cần billing, không cần key — khỏi lo vụ Maps billing riêng.

## Kiến trúc

```
iPhone (app này)                        ESP32-C3 HUD
┌─────────────────────┐   BLE GATT    ┌──────────────────────┐
│ Apple MapKit        │ ────────────► │ Màn hình OLED:       │
│ (bản đồ + MKDirections)  JSON       │ icon rẽ, tốc độ,     │
│ + GPS (tốc độ)      │               │ tên đường, ETA,      │
│ + BLE gửi dữ liệu   │               │ % pin, thanh tiến độ │
└─────────────────────┘               └──────────────────────┘
```

- **Service UUID:** `DD3F0AD1-6239-4E1F-81F1-91F6C9F01D86` (giữ nguyên của Sygic để tương thích firmware cũ)
- **Char WRITE:** `DD3F0AD3-...` — app ghi JSON vào đây
- Firmware ESP32: dùng bản **V7** (nhận JSON)

## JSON gửi tới ESP32 (mỗi ~1 giây)

```json
{
  "speed": 55,
  "distance": 240,
  "next_road": "đường Nguyễn Huệ",
  "next_road_sub": "Rẽ trái vào đường Nguyễn Huệ",
  "current_road": "đường Lê Lợi",
  "turn_road": "đường Nguyễn Huệ",
  "turn_text": "Rẽ trái vào đường Nguyễn Huệ",
  "eta": "13:05",
  "ete": "1 giờ 20 phút",
  "total_distance": "25.4 km",
  "maneuver": "left"
}
```

`maneuver`: `left` | `right` | `straight` | `uturn` | `arrive`

- Khi còn **trên 100 m** trước một thao tác rẽ, app gửi `maneuver: straight` để ESP32 giữ icon ↑.
- Khi còn **≤100 m**, app gửi hướng thật (`left/right/uturn`) và `next_road` là tên đường sẽ rẽ vào.
- `next_road_sub` / `turn_text` giữ nguyên câu chỉ dẫn đầy đủ để debug nếu cần.

---

# 📋 HƯỚNG DẪN TỪNG BƯỚC (cậu chủ làm theo thứ tự)

## Bước 1 — Đẩy code lên GitHub (repo RIÊNG TƯ — private!)

1. Tạo tài khoản GitHub (https://github.com) nếu chưa có
2. Tạo repo mới tên `hohidrive-hud` → chọn **Private**
3. Trên máy Windows, cài **Git** (https://git-scm.com) nếu chưa có
4. Giải nén zip dự án này → mở cmd trong thư mục → gõ:
```bat
git init
git add .
git commit -m "Hohi Drive HUD iOS"
git branch -M main
git remote add origin https://github.com/<TEN_TAI_KHOAN>/hohidrive-hud.git
git push -u origin main
```

## Bước 2 — Build tự động (GitHub Actions, miễn phí)

1. Vào repo trên GitHub → tab **Actions** → workflow "Build iOS" tự chạy khi push
2. Đợi ~10-15 phút
3. Xong → bấm vào workflow run → kéo xuống **Artifacts** → tải file **`CatDriveHUD.ipa`**

## Bước 3 — Cài lên iPhone bằng AltStore (miễn phí)

1. Trên Windows: tải **AltServer** tại https://altstore.io → cài đặt (cần **iTunes + iCloud** từ Microsoft Store)
2. Cắm iPhone vào máy (tin cậy máy tính), bật **WiFi** (cùng mạng với máy)
3. Chạy AltServer (icon ở khay hệ thống) → **Install AltStore** → chọn iPhone → nhập **Apple ID**
4. Mở app **AltStore** trên iPhone → tab **My Apps** → dấu **+** → chọn file `.ipa` → nhập Apple ID → cài xong
5. App có trên màn hình chính → Cài đặt → Cài đặt chung → Quản lý VPN & Thiết bị → **Tin cậy** nhà phát triển → mở app, cho phép **Vị trí + Bluetooth**

⚠️ **7 ngày:** app free sign hết hạn sau 7 ngày — AltStore tự refresh nếu iPhone cùng WiFi với máy chạy AltServer.

## Bước 4 — Sử dụng

1. Bật ESP32 HUD (firmware V7 nhận JSON)
2. Mở app → gõ điểm đến (có **gợi ý hiện khi gõ**, tiếng Việt được) → bấm **Đi**
3. App vẽ tuyến đường trên bản đồ Apple, bắt đầu dẫn đường → ESP32 hiển thị icon rẽ, tốc độ, tên đường, ETA
4. Mất kết nối BLE → app **tự kết nối lại**

---

# Cấu trúc dự án

```
ios-app/
├── project.yml                  ← cấu hình XcodeGen (sinh project khi build)
├── .github/workflows/build.yml  ← GitHub Actions build .ipa
└── CatDriveHUD/
    ├── AppDelegate.swift        ← khởi tạo app
    ├── ViewController.swift     ← bản đồ Apple + tìm kiếm gợi ý + dẫn đường
    ├── BLEManager.swift         ← kết nối ESP32 + auto-reconnect
    └── NavigationManager.swift  ← MKDirections (tính tuyến đường, miễn phí)
```
