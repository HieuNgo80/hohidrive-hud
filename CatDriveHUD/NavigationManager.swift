import Foundation
import CoreLocation
import MapKit

/// Một bước rẽ trong tuyến đường (từ Apple MapKit / MKDirections)
struct RouteStep {
    let instruction: String   // chỉ dẫn: "Rẽ trái vào Lê Lợi"
    let maneuver: String      // left | right | straight | arrive
    let endLat: Double
    let endLng: Double
    let distance: Int         // mét tới hết bước này
    let durationValue: Int    // giây đi hết bước này
}

/// Lấy tuyến đường bằng Apple MapKit (MKDirections) — miễn phí, không cần API key
class NavigationManager {

    /// Tính tuyến đường, trả về steps + thông tin tổng + tọa độ polyline để vẽ
    func fetchRoute(from: CLLocationCoordinate2D,
                    to: CLLocationCoordinate2D,
                    completion: @escaping ([RouteStep], Int, String, [CLLocationCoordinate2D]) -> Void) {

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                DispatchQueue.main.async { completion([], 0, "", []) }
                return
            }

            // Tổng: thời gian + khoảng cách
            let totalDurationSec = Int(route.expectedTravelTime)
            let totalDistanceText = Self.formatDistance(route.distance)
            let totalDistance = route.steps.reduce(0.0) { $0 + $1.distance }

            // Từng bước rẽ (MKRouteStep) — MapKit không cho thời gian từng step,
            // nên chia tổng thời gian theo tỷ lệ quãng đường của từng bước
            var steps: [RouteStep] = []
            for s in route.steps {
                // Điểm cuối của bước này = điểm cuối polyline của step
                let pts = s.polyline.points()
                let end = pts[s.polyline.pointCount - 1].coordinate
                let stepDuration = totalDistance > 0
                    ? Int(Double(s.distance) / totalDistance * Double(totalDurationSec))
                    : 0
                steps.append(RouteStep(
                    instruction: s.instructions,
                    maneuver: Self.mapManeuver(s.instructions),
                    endLat: end.latitude,
                    endLng: end.longitude,
                    distance: Int(s.distance),
                    durationValue: stepDuration
                ))
            }

            // Tọa độ polyline tổng (để vẽ tuyến đường)
            var coords: [CLLocationCoordinate2D] = []
            let routePts = route.polyline.points()
            for i in 0..<route.polyline.pointCount {
                coords.append(routePts[i].coordinate)
            }

            DispatchQueue.main.async {
                completion(steps, totalDurationSec, totalDistanceText, coords)
            }
        }
    }

    /// Định dạng khoảng cách mét -> "25.4 km" / "800 m"
    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    /// Đoán maneuver từ chữ chỉ dẫn của Apple (tiếng Việt/Anh)
    static func mapManeuver(_ instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("trái") || lower.contains("left") { return "left" }
        if lower.contains("phải") || lower.contains("right") { return "right" }
        if lower.contains("đến nơi") || lower.contains("điểm đến")
            || lower.contains("arrive") || lower.contains("destination") { return "arrive" }
        return "straight"
    }

    /// Tính các điểm tuyến đường phía trước dạng tọa độ TƯƠNG ĐỐI so với xe
    /// để firmware vẽ mini map heading-up: dx > 0 = bên phải, dy > 0 = phía trước (đơn vị mét)
    /// - Returns: [[dx,dy], ...] tối đa 20 điểm, mỗi điểm cách nhau ~12m
    static func relativeRoutePoints(from location: CLLocation,
                                    routeCoords: [CLLocationCoordinate2D]) -> [[Int]] {
        guard routeCoords.count > 1 else { return [] }

        let lat0 = location.coordinate.latitude
        let lng0 = location.coordinate.longitude

        // Heading: ưu tiên course của GPS; nếu không có thì đoán từ 2 điểm polyline gần nhất
        var heading = location.course
        if heading < 0 {
            var nearest = 0
            var best = Double.greatestFiniteMagnitude
            for (i, p) in routeCoords.enumerated() {
                let d = CLLocation(latitude: p.latitude, longitude: p.longitude)
                    .distance(from: location)
                if d < best { best = d; nearest = i }
            }
            let a = routeCoords[nearest]
            let b = routeCoords[min(nearest + 1, routeCoords.count - 1)]
            let dLat = b.latitude - a.latitude
            let dLng = b.longitude - a.longitude
            heading = atan2(dLng * cos(a.latitude * .pi / 180), dLat) * 180 / .pi
        }
        if heading < 0 { heading += 360 }
        let h = heading * .pi / 180
        let cosH = cos(h)
        let sinH = sin(h)

        // Tìm điểm polyline gần xe nhất -> bắt đầu lấy từ đó
        var startIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, p) in routeCoords.enumerated() {
            let d = CLLocation(latitude: p.latitude, longitude: p.longitude)
                .distance(from: location)
            if d < bestDist { bestDist = d; startIdx = i }
        }

        var result: [[Int]] = []
        var last = routeCoords[startIdx]
        var accumulated: Double = 0
        let spacing: Double = 12 // mét giữa các điểm gửi đi

        func appendPoint(_ p: CLLocationCoordinate2D) {
            let dLat = (p.latitude - lat0) * 111320
            let dLng = (p.longitude - lng0) * 111320 * cos(lat0 * .pi / 180)
            let forward = dLat * cosH + dLng * sinH   // dy: phía trước
            let right = -dLat * sinH + dLng * cosH    // dx: bên phải
            result.append([Int(right.rounded()), Int(forward.rounded())])
        }

        appendPoint(last)
        for i in (startIdx + 1)..<routeCoords.count {
            let p = routeCoords[i]
            accumulated += CLLocation(latitude: p.latitude, longitude: p.longitude)
                .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
            if accumulated >= spacing {
                appendPoint(p)
                last = p
                accumulated = 0
                if result.count >= 20 { break }
            }
        }
        return result
    }

    /// Cách 2 (v14): app tự vẽ bitmap mini map 1-bit 128x64 từ các điểm tuyến đường
    /// (heading-up: xe giữa màn, dy>0 vẽ LÊN TRÊN) rồi pack thành 1-bit giống SSD1306
    /// - Returns: 1024 bytes, mỗi byte 8 pixel ngang (bit 7 = pixel trái nhất)
    static func makeMapBitmap(routePoints: [[Int]],
                              width: Int = 128,
                              height: Int = 64) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let carX = width / 2
        let carY = height / 2 + 6

        // Scale giống firmware: vừa theo chiều cao phía trước + chiều ngang
        var maxDy = 10, maxDx = 10
        for p in routePoints where p.count >= 2 {
            maxDy = max(maxDy, p[1])
            maxDx = max(maxDx, abs(p[0]))
        }
        let scale = min(Float(carY - 4) / Float(maxDy),
                        Float(width / 2 - 6) / Float(maxDx + 4))
        let s = scale > 2.0 ? 2.0 : (scale < 0.05 ? 0.05 : scale)

        // Chuyển các điểm sang tọa độ pixel
        var pts: [(Int, Int)] = []
        for p in routePoints where p.count >= 2 {
            let x = carX + Int(Float(p[0]) * s)
            let y = carY - Int(Float(p[1]) * s)
            pts.append((x, y))
        }

        func setPixel(_ x: Int, _ y: Int) {
            if x >= 0 && x < width && y >= 0 && y < height {
                pixels[y * width + x] = 1
            }
        }

        // Bresenham line
        func drawLine(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) {
            var x0 = x0, y0 = y0
            let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
            let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
            var err = dx + dy
            while true {
                setPixel(x0, y0)
                if x0 == x1 && y0 == y1 { break }
                let e2 = 2 * err
                if e2 >= dy { err += dy; x0 += sx }
                if e2 <= dx { err += dx; y0 += sy }
            }
        }

        // Vẽ polyline tuyến đường
        if pts.count >= 2 {
            for i in 1..<pts.count {
                drawLine(pts[i - 1].0, pts[i - 1].1, pts[i].0, pts[i].1)
            }
        }

        // Vẽ xe: chấm tròn giữa màn
        for dy in -2...2 {
            for dx in -2...2 where dx * dx + dy * dy <= 4 {
                setPixel(carX + dx, carY + dy)
            }
        }

        // Pack thành 1-bit (giống Adafruit SSD1306 drawBitmap)
        var bytes = [UInt8](repeating: 0, count: width * height / 8)
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] == 1 {
                bytes[y * (width / 8) + x / 8] |= UInt8(1 << (7 - (x % 8)))
            }
        }
        return bytes
    }
}
