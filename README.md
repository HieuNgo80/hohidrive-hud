# CatDrive HUD — App iOS (Google Maps) + ESP32

App điều hướng **Google Maps** trên iPhone, gửi dữ liệu qua **BLE** tới ESP32-C3 HUD.
Không cần Mac, không tốn chi phí: build bằng GitHub Actions (macOS đám mây) + cài bằng AltStore (Apple ID thường).

## Kiến trúc

```
iPhone (app này)                        ESP32-C3 HUD
┌─────────────────────┐   BLE GATT    ┌──────────────────────┐
│ Google Maps SDK     │ ────────────► │ Màn hình OLED:       │
│ + Directions API    │   JSON        │ icon rẽ, tốc độ,     │
│ + GPS (tốc độ)      │               │ tên đường, ETA,      │
│ + BLE gửi dữ liệu   │               │ % pin, thanh tiến độ │
└─────────────────────┘               └──────────────────────┘
```

- **Service UUID:** `DD3F0AD1-6239-4E1F-81F1-91F6C9F01D86` (giữ nguyên của Sygic để tương thích firmware cũ)
- **Char WRITE:** `DD3F0AD3-...` — app ghi JSON vào đây
- Firmware ESP32: dùng bản **V7** (nhận JSON) — làm sau bước này

## JSON gửi tới ESP32 (mỗi ~1 giây)

```json
{
  "speed": 55,
  "distance": 240,
  "next_road": "Đi về hướng tây trên đường Nguyễn Huệ",
  "next_road_sub": "",
  "eta": "13:05",
  "ete": "1 giờ 20 phút",
  "total_distance": "25.4 km",
  "maneuver": "left"
}
```

`maneuver`: `left` | `right` | `straight` | `arrive`

---

# 📋 HƯỚNG DẪN TỪNG BƯỚC (cậu chủ làm theo thứ tự)

## Bước 1 — Tạo Google Cloud + API key (miễn phí, ~15 phút)

1. Vào https://console.cloud.google.com → đăng nhập Google → **Create Project** (đặt tên ví dụ `hohidrive-hud`)
2. Bật 2 API:
   - **Maps SDK for iOS** (tìm "Maps SDK for iOS" → Enable)
   - **Directions API** (tìm "Directions API" → Enable)
3. Vào **APIs & Services → Credentials → Create Credentials → API key**
4. Bấm vào key vừa tạo → **Restrict key**:
   - **API restrictions:** chỉ chọn `Maps SDK for iOS` + `Directions API`
   - **Application restrictions:** chọn **iOS apps** → thêm Bundle ID: `com.hohifamily.hohidrivehud`
   - (Restrict để kẻ khác lấy key cũng không dùng được — an toàn)
5. Copy chuỗi key (dạng `AIza...`)
6. **Bảo vệ ví:** vào **Billing** → gắn thẻ Visa (bắt buộc để dùng API) — Google tặng **$200/tháng free**, dùng cá nhân không bao giờ chạm tới. Để chắc ăn: vào **Budget alerts** đặt ngân sách **$1** → vượt là bị chặn, không thể trừ tiền.

## Bước 2 — Điền API key vào app

Mở file `CatDriveHUD/Info.plist`, sửa dòng:
```xml
<key>GoogleMapsAPIKey</key>
<string>AIza...PASTE_KEY_VAO_DAY</string>
```

## Bước 3 — Đẩy code lên GitHub (repo RIÊNG TƯ — private!)

1. Tạo tài khoản GitHub (https://github.com) nếu chưa có
2. Tạo repo mới tên `hohidrive-hud` → chọn **Private** (quan trọng: key Google không lộ)
3. Trên máy Windows, cài **Git** (https://git-scm.com) nếu chưa có
4. Giải nén zip dự án này → mở cmd trong thư mục → gõ:
```bat
git init
git add .
git commit -m "CatDrive HUD iOS"
git branch -M main
git remote add origin https://github.com/<TEN_TAI_KHOAN>/hohidrive-hud.git
git push -u origin main
```

## Bước 4 — Build tự động (GitHub Actions, miễn phí)

1. Vào repo trên GitHub → tab **Actions** → thấy workflow "Build iOS" → bấm **Run workflow**
2. Đợi ~10-15 phút (lần đầu tải Google Maps SDK lâu)
3. Xong → bấm vào workflow run → kéo xuống **Artifacts** → tải file **`CatDriveHUD.ipa`**

## Bước 5 — Cài lên iPhone bằng AltStore (miễn phí)

1. Trên Windows: tải **AltServer** tại https://altstore.io → cài đặt (cần **iTunes + iCloud** từ Microsoft Store)
2. Cắm iPhone vào máy (tin cậy máy tính), bật **WiFi** (cùng mạng với máy)
3. Chạy AltServer (icon ở khay hệ thống) → **Install AltStore** → chọn iPhone → nhập **Apple ID** (không cần trả $99!)
4. Mở app **AltStore** trên iPhone → tab **My Apps** → dấu **+** → chọn file `.ipa` đã tải → nhập Apple ID → cài xong
5. App có trên màn hình chính → mở ra, cho phép **Vị trí + Bluetooth**

⚠️ **7 ngày:** app free sign hết hạn sau 7 ngày — AltStore tự refresh nếu iPhone cùng WiFi với máy chạy AltServer. Cứ để AltStore mở là tự gia hạn.

## Bước 6 — Sử dụng

1. Bật ESP32 HUD (firmware V7 nhận JSON — ta giao sau bước này)
2. Mở app → nhập điểm đến (địa chỉ tiếng Việt được) → bấm **Đi**
3. App vẽ tuyến đường trên bản đồ, bắt đầu dẫn đường → ESP32 hiển thị icon rẽ, tốc độ, tên đường, ETA
4. Mất kết nối BLE → app **tự kết nối lại** (đã xử lý phản hồi "hay mất tín hiệu" của V5)

---

# Cấu trúc dự án

```
ios-app/
├── project.yml                  ← cấu hình XcodeGen (sinh project khi build)
├── .github/workflows/build.yml  ← GitHub Actions build .ipa
└── CatDriveHUD/
    ├── AppDelegate.swift        ← khởi tạo Google Maps
    ├── ViewController.swift     ← bản đồ + nhập đích + dẫn đường
    ├── BLEManager.swift         ← kết nối ESP32 + auto-reconnect
    ├── NavigationManager.swift  ← Directions API + theo dõi bước rẽ
    └── Info.plist               ← quyền + API key
```
